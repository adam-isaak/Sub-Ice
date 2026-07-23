%% Sub-Ice: DEM-based semi-automized mapping of ice shelf basal channels
%  Configuration file to be read by main scripts, for configuring filepaths
%  to input/output data, centerline search parameters and other user 
%  specifiable parameters. Update parameters as required! 
% 
%  (c) Dylan Kreynen
%  University of Oslo
%  2024-2026
% 
%  originally a project at the Int. Summer School in Glaciology
%  project team members: Marcelo Santis & Dylan Kreynen
%  advisor: Karen Alley (University of Manitoba)
%  McCarthy (AK), June 2024

% clear console, workspace, and close all instances 
clear all
close all
clc

%% Inputs
input_path = "./config.m";     % Input config file or folder specifiyin the location of the configuration files to run multiple

map_timeseries = 0;             % Control for whehter it should run a timeseries or not

% folder controls
config_match = "^config.*\.m$";     % Regex statement to match the config file
                                    % e.g. "^config.*\.m$" matches to any files that begin with "config" and end in ".m"
recursive = 1;                      % Whether or not if it is a folder we should look for any config files in sub-folders, and their sub folders

%% Overides
% overides default config variables when running through multiple configs
over_ext_figs = [0, 0];     % overrides ext_figs, based on the first value, and assigns it the second value
over_save_figs = [0, 0];    % overrides save_figs, based on the first value, and assigns it the second value
over_save_shps = [0, 0];    % overrides save_shps, based on the first value, and assigns it the second value
over_save_struct = [0, 0];  % overrides save_struct, based on the first value, and assigns it the second value
over_save_table = [0, 0];   % overrides save_table, based on the first value, and assigns it the second value

%% Run 
% add "functions" directory to search path
addpath("./functions")


% Runs the input manger 
run input_manager

% NOTES
% all figures are given an number ID based on the configuration file, channel number, and figure number
% Format XXXX-YYY-ZZ (X configuration file number, Y channel in configuration file number, Z figure number)
% Maximums (you will run out of memory before these limits ):
%    2146 - configurations files
%    999  - channels per configuration file
%    99   - unique figures per channel
