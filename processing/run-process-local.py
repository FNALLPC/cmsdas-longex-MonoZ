from coffea.nanoevents import NanoEventsFactory, BaseSchema
from coffea.dataset_tools import (
    apply_to_fileset,
    max_chunks,
    preprocess,
)
from coffea import processor

import argparse
import copy
import dask
import gzip, pickle, json
import pprint
import rich
import warnings
import yaml
from matplotlib.pyplot import hist
from dask.diagnostics import ProgressBar
from dask.distributed import Client
from dasmonoz.monoz import MonoZ
from dasmonoz.sumw import EventSumw

def main():
    parser = argparse.ArgumentParser("")
    # parser.add_argument('-jobs' , '--jobs'  , type=int, default=10    , help="")
    # parser.add_argument('-era'    , '--era' , type=str, default="2018", help="")
    parser.add_argument('--datasets', type=str, default='./data/datasets.yaml', help='input dataset yaml')
    parser.add_argument('-maxchunks', '--maxchunks', type=int, default= -1, help="limit number of chunks per-file to this number at most, default '-1' to process all")
    parser.add_argument('-ncores', '--ncores', type=int, default=1, help="Number of cores to run dask on locally: 1 uses default scheduler, more creates a distributed LocalCluster")
    parser.add_argument('--mode', type=str, default='virtual', help='mode for NanoEventsFactory in coffea, "virtual" default, "dask" as test option')
     
    options  = parser.parse_args()
    
    datasets:dict = dict()
    with open(options.datasets, 'r') as f:
        try:
            datasets = yaml.safe_load(f)
        except yaml.YAMLError as exc:
            print(exc) 
    
    datasets_sumw = copy.deepcopy(datasets)
    datasets_simu = copy.deepcopy(datasets)
    datasets_data = copy.deepcopy(datasets)
    
    for dataset in datasets:
        datasets_sumw[dataset]["files"] = {k: "Runs" for k in datasets[dataset]["files"]}
    
    datasets_sumw = {k:v for k,v in datasets_sumw.items() if v["metadata"]["is_mc"]}
    datasets_simu = {k:v for k,v in datasets_simu.items() if v["metadata"]["is_mc"]}
    datasets_data = {k:v for k,v in datasets_data.items() if "Run20" in k}

    weight_syst_list = ["puWeight", "PDF", "MuonSF", "ElecronSF", "EWK", "nvtxWeight", "TriggerSFWeight", "btagEventWeight",
                        "QCDScale0w", "QCDScale1w", "QCDScale2w"]
    shift_syst_list = ["ElectronEn", "MuonEn", "jesTotal", "jer"]

    bh_output = {}

    if options.mode == "dask":
        if options.ncores > 1:
            warnings.filterwarnings("ignore")
            client = Client(processes=True, threads_per_worker=1, n_workers=options.ncores, memory_limit='4GB')
            print("Dashboard:", client.dashboard_link)

        print("Processing MC Events ... ")
        for ds_name, ds_values in datasets_simu.items():
            print(i, len(c['files']))
            dataset_temp = {i: ds_values}
            dataset_mc_runnable, _ = preprocess(
                dataset_temp,
                align_clusters=False,
                step_size=100_000,
                files_per_batch=1,
                skip_bad_files=True,
                save_form=True,
            )

            event_mc_compute = apply_to_fileset(
                MonoZ(weight_syst_list=weight_syst_list, shift_syst_list=shift_syst_list),
                max_chunks(dataset_mc_runnable, options.maxchunks) if options.maxchunks > 0 else None,
                schemaclass=BaseSchema,
            )

            (histograms_simu,) = dask.compute(event_mc_compute)

            sumw_value = -1.0
            if ds_values['metadata']["is_mc"]:
                sumw_value= sumw[ds_name]
            bh_output[ds_name] = {
                "hist": histograms_simu[ds_name],
                "sumw": sumw_value
            }

    elif options.mode == "virtual":
        if options.ncores > 1:
            exc = processor.FuturesExecutor(compression=None)
        else:
            exc = processor.IterativeExecutor(compression=None)

        runner = processor.Runner(
            executor=exc,
            schema=BaseSchema,
            chunksize=100_000,
            maxchunks=options.maxchunks if options.maxchunks > 0 else None,
            savemetrics=True,
        )

        print("Processing MC Events ... ")
        histograms_simu, histograms_simu_metrics = runner(
            datasets_simu,
            processor_instance=MonoZ(weight_syst_list=weight_syst_list, shift_syst_list=shift_syst_list, virtual=True),
        )

        print("Processing Sumw ... ")
        sumw, sumw_metrics = runner(
            datasets_sumw,
            processor_instance=EventSumw(virtual=True),
        )

        for ds_name in histograms_simu.keys():
            bh_output[ds_name] = {
                "hist": histograms_simu[ds_name],
                "sumw": sumw[ds_name]
            }

        print("Processing Data Events ... ")
        warnings.filterwarnings('ignore', category=UserWarning) # to silence duplicate branch warnings in Data
        histograms_data, histograms_data_metrics = runner(
            datasets_data,
            processor_instance=MonoZ(weight_syst_list=weight_syst_list, shift_syst_list=shift_syst_list, virtual=True),
        )
        for ds_name in histograms_data.keys():
            bh_output[ds_name] = {
                "hist": histograms_data[ds_name],
                "sumw": -1.0
            }

    # rich.print(bh_output)

    with gzip.open("histograms.pkl.gz", "wb") as f:
        pickle.dump(bh_output, f)

    
    
    

if __name__ == "__main__":
    # This progress bar should work for local dask clusters; for dask.distributed, try the dask.distributed.progress function instead

    ProgressBar().register()
    main()

