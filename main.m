%% Main script
% clear all, close all;

%% Global options
GO_SHOW_CHANGE = false;
GO_SHOW_MASK = true;
GO_SHOW_PRETTIFIED = true;
GO_SHOW_ROC_CURVE = false;

GO_BAND_PRE_NORM = false;

GO_CONFIG_ROC = {};
GO_VERBOSE = true;
GO_SAVE_RESULTS = false;
GO_OUT_FILE_PATH = './results.mat';

% PAUSE MODES:
% -1: resume next iteration when all figures closed; 
% -2: press any key to continue
GO_PAUSE_MODE = 1;  

PAUSE_EACH_ITER_ = GO_SHOW_CHANGE | GO_SHOW_MASK | GO_SHOW_PRETTIFIED | GO_SHOW_ROC_CURVE;

%% Opt and configure the IMPORTANT ones
%{
	Available algorithms: CVA, DPCA, ImageDiff, ImageRatio, Image Regr,
	IRMAD, KPCA, MAD, MBPCA, PCDA

	Available datasets: BernDataset, TaizhouDataset

	Available binarization algorithms: FixedThre, KMeans, OTSU

	Available metrics: Acc, AUC, CDMetric, FMeasure, OA, Recall
%}
ALG = 'PCDA'
DATASET = 'TaizhouDataset'
THRE_ALG = 'KMeans'
METRICS = {'OA', 'UA', 'Recall', 'FMeasure', 'AUC', 'Kappa'}

CONFIG_ALG = {};
% CONFIG_DATASET = {'E:\��������\�ο�����\���ǳ�\����\Ottawa'};
% CONFIG_DATASET = {'D:\\data\\CD\\OSCD\\OSCDDataset'};
% CONFIG_DATASET = {'D:\\data\\CD\\Air Change dataset\\SZTAKI_AirChange_Benchmark'};
CONFIG_DATASET = {'E:\\��������\\��Ŀ\\�仯���\\Change Detection Code\\data\\Taizhou'};
% CONFIG_DATASET = {'E:\\��������\\�ο�����\\���ǳ�\\����\\Bern'};
CONFIG_THRE_ALG = {};
CONFIG_METRICS = {{}, {}, {}, {}, {}, {}};

% Check it
if GO_SHOW_ROC_CURVE
    [~, loc] = ismember('AUC', METRICS);
    if loc == 0
        error('AUC was not included in the desired metrics');
    end
end

%% Construct objects
alg = Algorithms.(ALG)(CONFIG_ALG{:});
dataset = Datasets.(DATASET)(CONFIG_DATASET{:});
iterDS = Datasets.CDDIterator(dataset);
threAlg = ThreAlgs.(THRE_ALG)(CONFIG_THRE_ALG{:});
nMetrics = length(METRICS);
metrics = cell(1, nMetrics);
for ii = 1:nMetrics
    metrics{ii} = Metrics.(METRICS{ii})(CONFIG_METRICS{ii}{:});
end
                
%% Main loop
while(iterDS.hasNext())
    % Fetch data
    [t1, t2, ref] = iterDS.nextChunk();
    
    if GO_BAND_PRE_NORM
        % Perform a band-wise z-score normalization before any further
        % algorithm is applied
        fcnNorm = @Utilities.normMeanStd;
        [t1, t2] = deal(fcnNorm(double(t1)), fcnNorm(double(t2)));
    end
    
    % Make difference image
    DI = alg.detectChange(t1, t2);
    % Segment
    CM = threAlg.segment(DI);
    % Measure
    cellfun(@(obj) obj.update(CM, ref, DI), metrics);
    
    if GO_VERBOSE
        for ii = 1:nMetrics
            m = metrics{ii};
            fprintf('type: %s\n', METRICS{ii});
            fprintf('\tnewest: %f\n', m.val(end));
            fprintf('\taverage: %f\n', m.avg);
        end
        fprintf('\n')
    end
    
    if PAUSE_EACH_ITER_
        handles = [];
        if GO_SHOW_CHANGE
            figure('Name', 'Change Map'),
            chns = size(DI, 3);
            if  chns ~= 1 && chns ~=3
                imshow(Utilities.normMinMax(Utilities.mergeAvg(DI)));
            else
                imshow(Utilities.normMinMax(DI));
            end
            handles = [handles, gcf];
        end
        
        if GO_SHOW_MASK
            figure('Name', 'Change Mask'),
            imshow(CM);
            handles = [handles, gcf];
        end
        
        if GO_SHOW_PRETTIFIED
            figure('Name', 'Prettified Change Map'),
            imshow(Utilities.pretty(DI, CM, ref));
            handles = [handles, gcf];
        end
        
        if GO_SHOW_ROC_CURVE
            if ~exist('aucer', 'var')
                aucer = metrics{loc};
            end
            fig = aucer.plotROC(GO_CONFIG_ROC{:});
            handles = [handles, fig];
        end
        
        if (iterDS.hasNext())
            if GO_PAUSE_MODE == 1
                for h = handles
                    waitfor(h);
                end
            elseif GO_PAUSE_MODE == 2
                pause
            else
                ;
            end
        end
    end
end

%% Collate and save results
results = struct('name', alg.algName, 'threAlg', threAlg.algName, 'dataset', DATASET);
for ii = 1:nMetrics
    results.(METRICS{ii}) = metrics{ii}.avg;
end

if GO_SAVE_RESULTS
    save(GO_OUT_FILE_PATH, 'results');
end