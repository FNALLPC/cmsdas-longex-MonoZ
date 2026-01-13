from coffea import processor
import awkward as ak

class EventSumw(processor.ProcessorABC):
    def __init__(self, virtual=True):
        super().__init__()
        self.virtual = virtual

    def process(self, event): 
        dataset_name = event.metadata['dataset']
        is_mc = event.metadata.get("is_mc")
        
        if is_mc is None:
            is_mc = 'data' not in dataset_name.lower()
        
        sumw = 1.0
        if is_mc:
            try:
                sumw = ak.sum(event.genEventSumw)
            except:
                sumw = -1.0
        else:
            sumw = -1.0

        # adjust return type to include dataset name if using older Runner interface with virtual arrays, and just return sumw if using dask-awkward backend
        return {dataset_name: sumw} if self.virtual else sumw
    
    def postprocess(self, accumulator):
        return accumulator
