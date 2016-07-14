#!/usr/bin/env python

import os
import datetime
import argparse
import logging
import numpy as np
import pandas as pd

defaults = argparse.Namespace(
    max_mem = '2G',
    max_tmpfs = '20G',
    max_wallclock_time = '23:59:59',
    max_procs = 1
)

formatter = logging.Formatter('%(asctime)s %(name)4s %(levelname)8s %(message)s', '%Y-%m-%d %H:%M:%S')

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
handler = logging.StreamHandler()
handler.setFormatter(formatter)
handler.setLevel(logging.DEBUG)
logger.addHandler(handler)

def parse_args():
    arg_parser = argparse.ArgumentParser(description='SGE Array Scheduler')

    arg_parser.add_argument('--name', metavar='name', required=True, help='job name')
    arg_parser.add_argument('--dir-prefix', metavar='path', required=True, help='working directory prefix')
    arg_parser.add_argument('--params', metavar='filename', required=True, help='params file')
    arg_parser.add_argument('--max-procs', metavar='int', type=int, default=defaults.max_procs, help='max processes')
    arg_parser.add_argument('command', metavar='command', nargs='+', help='command to run')

    return arg_parser.parse_args()

def schedule_jobs(args):
    params = pd.read_csv(args.params)
    num_tasks = len(params)
    logger.info('Scheduling %d tasks', num_tasks)

    today = datetime.datetime.now()
    current_date = '%04d-%02d-%02d' % (today.year, today.month, today.day)
    working_dir = os.path.join(args.dir_prefix, current_date)

    logger.info('    working dir = %s', working_dir)

    resource_args = [
        'h_rt', defaults.max_wallclock_time,
        'mem',  defaults.max_mem,
        'tmpfs', defaults.max_tmpfs
    ]

    qsub_args = [
        '-N',   args.name,
        '-wd',  working_dir,
        '-t',   '1-%d' % num_tasks,
        '-pe mpi', str(args.max_procs),
    ]

    command = ' '.join([
        'qsub',
        ' '.join(qsub_args),
        ' '.join(['-l %s=%s' %(i[0], i[1]) for i in zip(resource_args[::2], resource_args[1::2])]),
        ' '.join(args.command),
        args.params
    ])

    logger.info('Scheduling Job: %s' % command)
    os.system(command)

def main(args):
    logger.info('Scheduler started')

    for arg, value in vars(args).items():
        logger.info('%16s: %s' % (arg, value))

    schedule_jobs(args)
    logger.info('Scheduler finished')

main(parse_args())

