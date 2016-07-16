#!/usr/bin/env python

import os
import datetime
import argparse
import logging
import sys
import yaml
import numpy as np
import pandas as pd

defaults = argparse.Namespace(
    max_mem = '2G',
    max_tmpfs = '20G',
    max_wallclock_time = '23:59:59',
    max_procs = 1
)

def parse_args():
    arg_parser = argparse.ArgumentParser(description='SGE Array Scheduler')

    arg_parser.add_argument('--config', required=True, help='config file')
    arg_parser.add_argument('--max-procs', type=int, default=defaults.max_procs, help='max processes')
    arg_parser.add_argument('command', nargs='+', help='command to run')

    return arg_parser.parse_args()

args = parse_args()

with open(args.config) as configfile: 
    config = yaml.load(configfile)

formatter = logging.Formatter('%(asctime)s %(name)4s %(levelname)8s %(message)s', '%Y-%m-%d %H:%M:%S')

log_level = config['logging']['level']
logger = logging.getLogger()
logger.setLevel(log_level)
handler = logging.StreamHandler()
handler.setFormatter(formatter)
handler.setLevel(log_level)
logger.addHandler(handler)

def schedule_jobs():
    today = datetime.datetime.now()
    current_date = '%04d_%02d_%02d' % (today.year, today.month, today.day)
    output_dir = os.path.join(config['output']['root'], current_date)
    params_file = os.path.join(output_dir, config['output']['params'])

    logger.info('Loading parameters from %s', params_file)
    params = pd.read_csv(params_file)
    num_tasks = len(params)
    logger.info('Scheduling %d tasks', num_tasks)

    resource_args = [
        'h_rt', defaults.max_wallclock_time,
        'mem',  defaults.max_mem,
        'tmpfs', defaults.max_tmpfs
    ]

    working_dir = os.path.expanduser(os.path.join(output_dir, "run"))

    if not os.path.isdir(working_dir):
        os.makedirs(working_dir)

    qsub_args = [
        '-N',   config['job']['name'],
        '-S',   '/bin/bash',
        '-wd',  working_dir,
        '-t',   '1-%d' % num_tasks,
        '-pe mpi', str(args.max_procs),
    ]

    command = ' '.join([
        'qsub',
        ' '.join(qsub_args),
        ' '.join(['-l %s=%s' %(i[0], i[1]) for i in zip(resource_args[::2], resource_args[1::2])]),
        ' '.join(args.command),
        ' '.join(['--config', args.config]),
        ' '.join(['--params', params_file])
    ])

    logger.info('Scheduling Job: %s' % command)
    os.system(command)

def main():
    logger.info('Scheduler started')

    for arg, value in vars(args).items():
        logger.info('%16s: %s' % (arg, value))

    schedule_jobs()
    logger.info('Scheduler finished')

main()