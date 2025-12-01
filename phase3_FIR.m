% Author: Greg Schneider, Abhay Ratti
% Phase 3 - Tasks 10-13: Cochlear Implant Simulation

% Parameters
n_channels = 16;
sample_rate = 16000; % Hz
playAudio = true; % Set to true to play the output sound (ignored if process_all is true)
process_all = true; % Set to true to process all files in the processed directory
inputDir = 'Project/Dataset/processed';
outputDir = 'Project/Dataset/reworked';
inputFile = 'Project/Dataset/processed/siren_mono_16k.wav'; % Used when process_all is false
validExts = {'.wav'}; % Valid audio extensions to process

function fileList = getFiles(inputDir, validExts)
    % Get all valid audio files from the input directory
    fileList = {};
    audioFiles = dir(fullfile(inputDir, '*.*'));
    for k = 1:numel(audioFiles)
        [~, ~, ext] = fileparts(audioFiles(k).name);
        if any(strcmpi(ext, validExts)) && ~audioFiles(k).isdir
            fileList{end+1} = fullfile(inputDir, audioFiles(k).name);
        end
    end

    if isempty(fileList)
        fprintf('No valid audio files found in %s\n', inputDir);
    else
        fprintf('Found %d valid audio files in %s\n', numel(fileList), inputDir);
        for i = 1:numel(fileList)
            fprintf('  %s\n', fileList{i});
        end
    end
end

function split_signals = split_frequency(n, sample_rate, signal)
    split_signals = cell(1, n);
    low_freq = 100; % Hz
    hi_freq = 8000; % Hz
    freq_step = (hi_freq - low_freq) / n;
    for i = 1:n
        band_low = low_freq + (i-1) * freq_step;
        band_high = low_freq + i * freq_step;
        % Design FIR bandpass filter with normalized frequencies
        fir_order = 128; % FIR filter order
        normalized_low = band_low / (sample_rate / 2);
        normalized_high = band_high / (sample_rate / 2);
        b = fir1(fir_order, [normalized_low, normalized_high], 'bandpass');
        split_signals{i} = filtfilt(b, 1, signal);
    end
end

function processed_signals = envelope_extraction(signals, sample_rate)
    processed_signals = cell(size(signals));
    for i = 1:length(signals)
        % Lowpass filter has a cutoff frequency of 400 Hz, and sample rate of 16 kHz
        % Outer Abs included since sometimes lowpass can produce small negative values
        % Design FIR lowpass filter with normalized frequency
        fir_order = 128; % FIR filter order
        normalized_cutoff = 400 / (sample_rate / 2);
        b = fir1(fir_order, normalized_cutoff, 'low');
        processed_signals{i} = abs(filtfilt(b, 1, abs(signals{i}))); % Rectification & Lowpass Filtering
    end
end

function cosine_signals = generate_channel_cosines(n, sample_rate, envelope_signals)
    % Task 10: Generate cosine signals at central frequency of each bandpass filter
    % Each cosine signal has the same length as the corresponding envelope signal
    
    cosine_signals = cell(1, n);
    low_freq = 100; % Hz
    hi_freq = 8000; % Hz
    freq_step = (hi_freq - low_freq) / n;
    
    for i = 1:n
        % Calculate the central frequency of this channel's bandpass filter
        band_low = low_freq + (i-1) * freq_step;
        band_high = low_freq + i * freq_step;
        center_freq = (band_low + band_high) / 2;
        
        % Get the length of the rectified/envelope signal for this channel
        num_samples = numel(envelope_signals{i});
        
        % Generate time vector
        t = (0:num_samples-1).' / sample_rate;
        
        % Generate cosine at the central frequency
        cosine_signals{i} = cos(2 * pi * center_freq * t);
        
        fprintf('Channel %d: Generated cosine at %.1f Hz (center of %.1f - %.1f Hz band)\n', ...
            i, center_freq, band_low, band_high);
    end
end

function modulated_signals = amplitude_modulate(cosine_signals, envelope_signals)
    % Task 11: Amplitude modulate each cosine signal using the envelope (rectified signal)
    % AM: modulated_signal = envelope * cosine
    
    n = length(cosine_signals);
    modulated_signals = cell(1, n);
    
    for i = 1:n
        % Amplitude modulation: multiply envelope by cosine carrier
        modulated_signals{i} = envelope_signals{i} .* cosine_signals{i};
    end
    
    fprintf('Amplitude modulated %d channels\n', n);
end

function output_signal = sum_and_normalize(modulated_signals)
    % Task 12: Add all modulated signals together and normalize
    
    % Initialize output with zeros (same size as first signal)
    output_signal = zeros(size(modulated_signals{1}));
    
    % Sum all modulated signals
    for i = 1:length(modulated_signals)
        output_signal = output_signal + modulated_signals{i};
    end
    
    % Normalize by the maximum of the absolute value
    max_abs = max(abs(output_signal));
    if max_abs > 0
        output_signal = output_signal / max_abs;
    end
    
    fprintf('Summed %d channels and normalized output signal\n', length(modulated_signals));
end

function play_and_save(output_signal, sample_rate, playAudio, outputDir, inputFileName)
    % Task 13: Play the output sound and write to a new file
    
    % Extract base name from input file
    [~, baseName, ~] = fileparts(inputFileName);
    
    % Play the audio if enabled
    if playAudio
        fprintf('Playing cochlear implant simulation output...\n');
        sound(output_signal, sample_rate);
        % Wait for playback to complete
        pause(length(output_signal) / sample_rate);
    end
    
    % Write to file
    outputFile = fullfile(outputDir, sprintf('%s_cochlear_output.wav', baseName));
    audiowrite(outputFile, output_signal, sample_rate);
    fprintf('Wrote output audio: %s\n', outputFile);
end

function process_file(filePath, n_channels, sample_rate, playAudio, outputDir)
    % Process a single audio file through the cochlear implant simulation
    
    [~, baseName, ~] = fileparts(filePath);
    fprintf('\n--- Processing: %s ---\n', baseName);
    
    % Load original signal
    fprintf('Loading input signal: %s\n', filePath);
    original_signal = audioread(filePath);
    
    % Split into frequency bands
    fprintf('Task 7: Splitting signal into %d frequency channels\n', n_channels);
    signals = split_frequency(n_channels, sample_rate, original_signal);
    
    % Extract envelopes (rectified signals) - Task 8
    fprintf('Task 8: Extracting envelopes from each channel\n');
    envelope_signals = envelope_extraction(signals, sample_rate);
    
    % Task 10: Generate cosines at central frequencies of each channel
    fprintf('Task 10: Generating cosine signals at central frequencies\n');
    cosine_signals = generate_channel_cosines(n_channels, sample_rate, envelope_signals);
    
    % Task 11: Amplitude modulate cosines with envelope signals
    fprintf('Task 11: Amplitude modulating cosine signals with envelopes\n');
    modulated_signals = amplitude_modulate(cosine_signals, envelope_signals);
    
    % Task 12: Sum all modulated signals and normalize
    fprintf('Task 12: Summing all modulated signals and normalizing\n');
    output_signal = sum_and_normalize(modulated_signals);
    
    % Task 13: Play and save output
    fprintf('Task 13: Saving output signal\n');
    play_and_save(output_signal, sample_rate, playAudio, outputDir, filePath);
end

% Ensure output directory exists
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Main Execution
if process_all
    % Process all files in the input directory
    fprintf('=== Phase 3: Processing ALL Files ===\n');
    files = getFiles(inputDir, validExts);
    
    if isempty(files)
        fprintf('No files to process.\n');
    else
        for fileIdx = 1:length(files)
            fprintf('\nProcessing file %d of %d\n', fileIdx, length(files));
            % When processing all files, don't play audio
            process_file(files{fileIdx}, n_channels, sample_rate, false, outputDir);
        end
        fprintf('\n=== Processed %d files successfully ===\n', length(files));
    end
else
    % Process single file
    fprintf('=== Phase 3: Processing Single File ===\n');
    process_file(inputFile, n_channels, sample_rate, playAudio, outputDir);
    fprintf('\n=== Phase 3 Complete ===\n');
end