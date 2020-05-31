classdef lookupMap < handle
    %LOOKUPTABLE Look up timing or channels from a containers.Map object
    %   Class for a lookuptable for finding times and channels
    %
    % Example
    % -------
    % a = lookup('../WT')  % pass a genotype directory
    % a = a.buildLookup() 
    % a.findTime(40)
    % a.findTime(40, 3)
    % a.findLabel('Eve')
    % a.findLabel('Runt')
    % a.findLabelTime('Eve', 40)
    % a.findLabelTime('Eve', 40, 3)
    %
    % testing
    % -------
    % keys = a.map('Eve').keys
    % for i = 1:length(keys)
    %   q = a.map('Eve') ;
    %   q(keys{i})
    % end
    % 
    % NPMitchell 2019
    
    properties
        genoDir
        timerfn
        prepend
        exten
        map = containers.Map
        % map contains as many keys as stainings. For ex, 'Runt' is a key
        % that returns a struct with fields
        %   times : 1xN float array
        %       the timestamps for each embryo
        %   uncs : 1xN float array
        %       the uncertainty in time for each embryo
        %   folders : 1xN string cell
        %       the folder containing the pullback for each embryo
        %   names : 1xN string cell
        %       file name within folder of the pullback image
        %   embryoIDs : 1xN string cell
        %       unique date identifier for each embryo
        %   nTimePoints : 1xN int array
        %       number of timepoints in the pullback
        
    end
    
    
    methods
        function obj = lookupMap(genoDir, timerfn, prepend, exten)
            obj.genoDir = genoDir ;
            if nargin < 1
                error('Must supply a directory to use (genoDir) for class instantiation')
            elseif nargin < 5
                exten = '.tif' ;    % string after channel index
                if nargin < 4
                    % filename for pullback without filetype extension
                    prepend = 'MAX_Cyl1_2_000000_c*_rot_scaled_view1' ;      
                    if nargin < 3
                        timerfn = 'timematch_Runt_chisq.mat' ;            
                    end
                end
            end
            obj.timerfn = timerfn ;
            obj.prepend = prepend ;
            obj.exten = exten ;
            
            % Assign to property of lookupMap instance
            obj.map = buildLookupMap(obj, false) ;
        end
        
        %BUILDLOOKUPMAP Construct the lookup map
        out = buildLookupMap(obj, save_map) ;
        
        function saveLookupMap(obj)
            %SAVELOOKUPMAP Save the constructed lookup map
            map = obj.map ;
            save_map(fullfile(obj.genoDir, 'lookuptable_containersMap.mat'), 'map') ;
        end
            
        function outstruct = findTime(obj, tfind, eps)
            %FINDTIME(tfind, eps) Find all instances with time near tfind
            %   Give the labels, folders, and time uncertainties of all
            %   stained samples matching the supplied time tfind, within
            %   a value eps of that time. Returns an output struct.
            %
            % Parameters
            % ----------
            % obj : the class instance of lookup
            % tfind : float or int timestamp
            % eps : optional, the allowed difference from tstamp
            
            if nargin < 3
                eps = 0.5 ;
                if nargin < 2
                    error("Must supply tfind (a time to search for) for class method findTime()")
                end
            end
            
            folders = {}; 
            embryoIDs = {} ;
            etimes = [] ;
            uncs = [] ; 
            dmyk = 1 ;
            % get all the labels
            labels = obj.map.keys ;
            % For each label, add struct.label, folders, uncs
            outstruct.labels = {} ;
            outstruct.folders = {} ;
            outstruct.embryoIDs = {} ;
            outstruct.times = [] ;
            outstruct.uncs = [] ;
            outstruct.tiffpages = [] ;
            for ii = 1:length(labels)
                label = labels{ii} ;
                substruct = obj.map(label) ; 
                timestamps = substruct.times ;
                for jj = 1:length(timestamps)
                    tstamps = timestamps{jj} ;
                    for kk = 1:length(tstamps) 
                        tstamp = tstamps(kk) ;
                        if abs(tstamp - tfind) < eps 
                            labels{dmyk} = label ; 
                            folders{dmyk} = substruct.folders{jj} ;
                            embryoIDs{dmyk} = substruct.embryoIDs{jj} ;
                            etimes(dmyk) = tstamp 
                            uncs(dmyk) = substruct.uncs(jj) ;
                            tiffpages(dmyk) = kk ;
                            dmyk = dmyk + 1 ;
                        end
                    end
                end
            end
            
            % Add to the output struct
            if ~isempty(embryoIDs)
                outstruct.labels{length(outstruct.labels) + 1} = labels ;
                outstruct.folders{length(outstruct.folders) + 1} = folders ;
                outstruct.embryoIDs{length(outstruct.embryoIDs) + 1} = embryoIDs ;
                length(outstruct.times)
                outstruct.times(length(outstruct.times) + 1) = etimes ;
                outstruct.uncs(length(outstruct.uncs) + 1) = uncs ;
                outstruct.tiffpages(length(outstruct.tiffpages) + 1) = tiffpages ;
            end
        end
        
        function labelstruct = findLabel(obj, label2find)
            %FINDLABEL(label2find) Find all embryos with given stain
            %   Give the times, folders, and time uncertainties of all
            %   stained samples matching the supplied channel 'label'
            %
            % Parameters
            % ----------
            % obj : the class instance of lookup
            % label : string, label name (ex 'Eve' or 'Runt')
            
            if nargin < 2
                error("Must supply label (a channel to search for) for class method findLabel()")
            end
            labelstruct = obj.map(label2find) ;
        end
        
        function outstruct = findStaticLabel(obj, label2find)
            %FINDDYNAMICLABEL(label2find) Find dynamic embryos with label
            %   Give the times, folders, and time uncertainties of all
            %   live samples matching the supplied channel 'label'
            %
            % Parameters
            % ----------
            % obj : the class instance of lookup
            % label2find : string, label name (ex 'Eve' or 'Runt')
            outstruct = buildStructWrtTime(obj, 'static', label2find) ;
        end
        
        function outstruct = findDynamicLabel(obj, label2find)
            %FINDDYNAMICLABEL(label2find) Find dynamic embryos with label
            %   Give the times, folders, and time uncertainties of all
            %   live samples matching the supplied channel 'label'
            %
            % Parameters
            % ----------
            % obj : the class instance of lookup
            % label2find : string, label name (ex 'Eve' or 'Runt')
            outstruct = buildStructWrtTime(obj, 'dynamic', label2find) ;
        end
        
        function outstruct = findLabelTime(obj, label2find, tfind, eps)
            %FINDTIME(tfind, eps) Find all instances with given channel
            %   Give the times, folders, and time uncertainties of all
            %   stained samples matching the supplied channel 'label'
            %
            % Parameters
            % ----------
            % obj : the class instance of lookup
            % label : string, label name (ex 'Eve' or 'Runt')
            % tfind : float or int timestamp
            % eps : optional, the allowed difference from tstamp
            %
            % Returns
            % -------
            % outstruct : struct
            %   The output structure with fields folders, times, uncs
            
            
            if nargin < 4
                eps = 0.5 ;
                if nargin < 3
                    error("Must supply both label and tfind for class method findLabelTime()")
                end
            end
            
            folders = {}; 
            names = {} ;
            embryoIDs = {}; 
            timepts = []; 
            uncs = []; 
            tiffpages = [] ;
            nTimePoints = [] ;
            dmyk = 1 ;
            % get all the labels
            labels = obj.map.keys ;
            % For each label, add struct.label, folders, uncs
            for ii = 1:length(labels)
                label = labels(ii) ;
                if strcmp(label, label2find)
                    substruct = obj.map(label{1}) ;
                    timestamps = substruct.times ;
                    % Consider each embryo and look for time matches
                    for jj = 1:length(timestamps)
                        tstamps = timestamps{jj} ;
                        % go through each page of the tiff and look for
                        % time matches
                        for kk = 1:length(tstamps) 
                            tstamp = tstamps(kk) ;
                            if abs(tstamp - tfind) < eps
                                folders{dmyk} = substruct.folders{jj} ;
                                names{dmyk} = substruct.names{jj} ;
                                embryoIDs{dmyk} = substruct.embryoIDs{jj} ;
                                timepts(dmyk) = tstamp ;
                                uncs{dmyk} = substruct.uncs{jj} ;
                                tiffpages(dmyk) = kk ;
                                nTimePoints(dmyk) = substruct.nTimePoints(jj) ;
                                dmyk = dmyk + 1 ;
                            end
                        end
                    end
                end
            end
            
            % Add to the output struct
            outstruct.folders = folders ;
            outstruct.names = names ;
            outstruct.embryoIDs = embryoIDs ;
            outstruct.times = timepts ;
            outstruct.uncs = uncs ;
            outstruct.tiffpages = tiffpages ;
            outstruct.nTimePoints = nTimePoints ;
        end
        
        function estruct = findEmbryo(obj, embryoID) 
            %FINDEMBRYO(embryoID) Find all instances with given embryo
            %   Give the names, folder, times, and time uncertainties for
            %   stained samples matching the supplied embryoID
            %
            % Parameters
            % ----------
            % obj : the class instance of lookup
            % embryoID : string, embryo identification name 
            %           (ex '201904011200')
            %
            % Returns
            % -------
            % estruct : struct
            %   The output structure with fields labels, folders, times, uncs
            
            elabels = {} ;
            folders = {} ; 
            names = {} ;
            embryoIDs = {} ;
            timepts = {} ;  % contains arrays for dynamic data, float for fixed data
            uncs = {} ; 
            nTimePoints = [] ;
            dmyk = 1 ;
            % get all the labels
            labels = obj.map.keys ;
            % For each label, add struct.label, folders, uncs
            for ii = 1:length(labels)
                label = labels(ii) ;
                label = label{1} ;
                substruct = obj.map(label) ;
                eIDs = substruct.embryoIDs ;
                for jj = 1:length(eIDs)
                    if strcmp(eIDs{jj}, embryoID)
                        elabels{dmyk} = label ;
                        folders{dmyk} = substruct.folders{jj} ;
                        names{dmyk} = substruct.names{jj} ;
                        embryoIDs{dmyk} = substruct.embryoIDs{jj} ;
                        timepts{dmyk} = substruct.times{jj} ;
                        uncs{dmyk} = substruct.uncs{jj} ;
                        nTimePoints(dmyk) = substruct.nTimePoints(jj) ;
                        dmyk = dmyk + 1 ;
                    end
                end
            end
            
            % Add to the output struct
            estruct.labels = elabels ;
            estruct.folders = folders ;
            estruct.names = names ;
            estruct.embryoIDs = embryoIDs ;
            estruct.times = timepts ;
            estruct.uncs = uncs ;
            estruct.nTimePoints = nTimePoints ; 
        end
        
        % Util methods
        outstruct = buildStructWrtTime(obj, timestr, label2find) ;
        
    end
    
end

