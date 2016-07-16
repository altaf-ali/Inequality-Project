CONFIG = $(PWD)/config.yaml

MAKE_PARAMS = $(PWD)/R/make_params.R

MERGE_GRIDS_R = $(PWD)/R/merge_grids.R
MERGE_GRIDS_SH = $(PWD)/bin/merge_grids.sh

SGE_ARRAY = $(PWD)/bin/sge_array.py

params:
	$(MAKE_PARAMS) --config $(CONFIG)

grids:
	$(SGE_ARRAY) --config $(CONFIG) $(MERGE_GRIDS_SH) $(MERGE_GRIDS_R)

all: params grids

.DEFAULT_GOAL := none

