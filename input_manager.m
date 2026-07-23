
% input_manager
% script to manage inputs from the sub-ice script, to run the configs, 
% and map_multi_channel

%% run configuration file - set user specifiable parameters
%  contains filepaths to input/output data, sets method to select channel
%  start/end points, configures centerline search parameters, output 
%  behaviour etc. > update configuration file as required! 

if(isfile(input_path))          % if a single file is specified find that specific file and run it as the configuration
    % set the default number of configs as 0
    config_num = 1;   
    
    % run the specified config file
    run(input_path)

    % run the overrides for the configuration files
    if(over_ext_figs(1))
        ext_figs = over_ext_figs(2);
    end
    if(over_save_figs(1))
        save_figs = over_save_figs(2);
    end
    if(over_save_shps(1))
        save_shps = over_save_shps(2);
    end
    if(over_save_struct(1))
        save_struct = over_save_struct(2);
    end 
    if(over_save_table(1))
        save_table = over_save_table(2);
    end

    % create output directories, if necessary
    if save_figs % figures
        fig_dir = append(results_dir, proj_subdir, fig_subdir); 
        if ~exist(fig_dir, 'dir')
            mkdir(fig_dir)
        end
    end

    if save_shps % shapefiles
        shp_dir = append(results_dir, proj_subdir, shp_subdir); 
        if ~exist(shp_dir, 'dir')
            mkdir(shp_dir)
        end
    end

    if save_struct || save_table % data
        data_dir = append(results_dir, proj_subdir, data_subdir);
        if ~exist(data_dir, 'dir')
            mkdir(data_dir)
        end
    end


    % Run the mapping behaviour 
    if (map_timeseries)
        run 'map_channel_timeseries.m'
    else 
        run 'map_multi_channel.m'
    end
elseif(isfolder(input_path))    % if the path is a folder find configs and iterate through them
    if(recursive)
        % finds all files in specifiefd folder and files in subfolders that end in `.m`
        input_folder = dir(fullfile(input_path, '**', '*.m'));
    else
        % finds all files and folders in the 
        input_folder = dir(fullfile(input_path, '*.m'));
    end
    
    % loop through all files 
    no_files = size(input_folder, 1);
    config_num = 1;
    for i = 1:no_files        
        % create the file path for the correct file
        file_path = string(append(input_folder(i).folder, '/', input_folder(i).name));
        if(~isempty(regexp(input_folder(i).name, config_match, 'match')))
            fprintf("Found and running through config-%d.\n", config_num)

            % run configuration file
            run(file_path)

            % run the overrides for the configuration files
            if(over_ext_figs(1))
                ext_figs = over_ext_figs(2);
            end
            if(over_save_figs(1))
                save_figs = over_save_figs(2);
            end
            if(over_save_shps(1))
                save_shps = over_save_shps(2);
            end
            if(over_save_struct(1))
                save_struct = over_save_struct(2);
            end 
            if(over_save_table(1))
                save_table = over_save_table(2);
            end

            % create output directories, if necessary
            if save_figs % figures
                fig_dir = append(results_dir, proj_subdir, fig_subdir); 
                if ~exist(fig_dir, 'dir')
                    mkdir(fig_dir)
                end
            end

            if save_shps % shapefiles
                shp_dir = append(results_dir, proj_subdir, shp_subdir); 
                if ~exist(shp_dir, 'dir')
                    mkdir(shp_dir)
                end
            end

            if save_struct || save_table % data
                data_dir = append(results_dir, proj_subdir, data_subdir);
                if ~exist(data_dir, 'dir')
                    mkdir(data_dir)
                end
            end

            % map the changes
            if (map_timeseries)
                run 'map_channel_timeseries.m'
            else 
                run 'map_multi_channel.m'
            end

            % increment the channel ID
            config_num = config_num + 1;
        end
    end
else
    error("'input_path' is invalid and neither a file or folder can be found.")
end