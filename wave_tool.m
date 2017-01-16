%% wave_tool script
[steering_file, working_dir] = uigetfile('*.txt', 'Select the steering file');
present_dir = cd(working_dir);

%% Get steering parameters
STEERING = GetParameters(steering_file, [key_dir filesep 'steering.key']);

%% Get ADCP and wave analysis parameters
CONFIG_ADCP = GetParameters(STEERING.ADCP_config_file, [key_dir filesep 'ADCP.key']);
CONFIG_WAVE = GetParameters(STEERING.WAVE_config_file, [key_dir filesep 'wave.key']);

%% Extract ADCP data 
matlab_data_file = [strtok(STEERING.wave_data_file, '.') '.mat'];
CONFIG_ADCP.wave_file_type = STEERING.wave_file_type;
if ~exist(matlab_data_file, 'file')
    if strcmp(STEERING.wave_file_type, 'PACKET'),
        
        %Extract wave packet data,update configuration and packet wave data
        [RAW,  CONFIG_WAVE, CONFIG_ADCP] = feval(['ADCP_WavePackets_BIN2RAW_' CONFIG_ADCP.wave_packet_reader_version], ...
                           STEERING.wave_data_file, CONFIG_ADCP, CONFIG_WAVE);
    else
        %Extract ensemble data,update configuration data,calculate surface track 
        [RAW,  CONFIG_WAVE, CONFIG_ADCP] = feval(['ADCP_Ensemble_BIN2RAW_' CONFIG_ADCP.wave_ensemble_reader_version], ...
                           STEERING.wave_data_file, CONFIG_WAVE, CONFIG_ADCP);
    end

    save(matlab_data_file, 'RAW', 'CONFIG_ADCP', 'CONFIG_WAVE', '-v7.3');
else
    % load ADCP data
    disp('Using raw data saved in MAT file');
    load(matlab_data_file, 'RAW', 'CONFIG_ADCP', 'CONFIG_WAVE');
end

%% Trim raw data
RAW = feval(['wave_trim_data_' CONFIG_WAVE.wave_trim_data_version], RAW, CONFIG_WAVE, CONFIG_ADCP);

%% Apply Tier 2 QC
RAW_QC = feval(['wave_QC_T2_' CONFIG_WAVE.wave_qc_t2_version], RAW, CONFIG_WAVE, CONFIG_ADCP);

%% Apply Tier 3 QC
RAW_QC = feval(['wave_QC_T3_' CONFIG_WAVE.wave_qc_t3_version],RAW_QC, CONFIG_WAVE, CONFIG_ADCP);

%% Calculate data point position and orientation (wave data definition)
WAVE = feval(['wave_define_geometry_' CONFIG_WAVE.wave_define_geometry_version],RAW_QC, CONFIG_WAVE, CONFIG_ADCP);

%% 1D analysis of "Pressure" data 
WAVE = feval(['wave_analysis_1D_' CONFIG_WAVE.wave_1d_analysis_version],WAVE, CONFIG_WAVE, CONFIG_ADCP, {'pressure'});

%% ID analysis of "surface track" signals
WAVE =  feval(['wave_analysis_1D_' CONFIG_WAVE.wave_1d_analysis_version],WAVE, CONFIG_WAVE, CONFIG_ADCP, {'surface_track', 'surface_track_vertical'});

%% ID analysis of "beam velocities"
WAVE = feval(['wave_analysis_1D_' CONFIG_WAVE.wave_1d_analysis_version],WAVE, CONFIG_WAVE, CONFIG_ADCP, {'beam_velocity'});

%% 2D analysis of selected data and  including cross-spectral signals, calculate currents, 2D analysis using
WAVE = feval(['wave_analysis_2D_' CONFIG_WAVE.wave_2d_analysis_version],WAVE, CONFIG_WAVE, CONFIG_ADCP);

%% calculate spectra using "PUV" method 
[WAVE.Dm_UVW, WAVE.Dstd_UVW] = feval(['wave_2D_analysis_UVW_' CONFIG_WAVE.wave_2d_analysis_uvw_version],RAW_QC, CONFIG_WAVE, CONFIG_ADCP);
 
%% save all data
save([CONFIG_ADCP.ADCP_ref '_processed_wave_' datestr(now,'yymmddHHMM')], '-v7.3');

%% return to original directory
cd(present_dir)











