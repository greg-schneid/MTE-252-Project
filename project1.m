
% Run phase1 for each file in /Dataset/selected
selectedDir = fullfile(pwd, 'Dataset', 'selected');
audioFiles = dir(fullfile(selectedDir, '*.*'));
validExts = {'.wav', '.flac', '.m4a', '.mp3'};
fileList = {};

for k = 1:numel(audioFiles)
    [~, ~, ext] = fileparts(audioFiles(k).name);
    if any(strcmpi(ext, validExts)) && ~audioFiles(k).isdir
        fileList{end+1} = fullfile(selectedDir, audioFiles(k).name); %#ok<AGROW>
    end
end

if isempty(fileList)
    fprintf('No valid audio files found in %s\n', selectedDir);
else
    fprintf('Found %d valid audio files in %s\n', numel(fileList), selectedDir);
    for i = 1:numel(fileList)
        fprintf('  %s\n', fileList{i});
    end
    phase1(fileList);
end

function phase1(filePaths)
% phase1: Read, normalize (mono), optionally resample to 16 kHz, analyze, and generate signals.
% Usage:
%   phase1                 % prompts to select one or more audio files
%   phase1({"file1.wav", "file2.m4a"})
%
% This script/function will do this:
% - Load one or more audio files using audioread
% - Convert stereo to mono by averaging channels
% - Play and write a cleaned mono version to disk
% - Resample to 16 kHz if original fs >= 16000 and fs ~= 16000
% - Plot waveform (sample index vs amplitude) for the first processed file
% - Generate a 1 kHz cosine matching the processed signal length and duration
% - Play the cosine and plot two cycles versus time

    if nargin < 1 || isempty(filePaths)
        [names, path] = uigetfile({'*.wav;*.flac;*.m4a;*.mp3','Audio Files (*.wav, *.flac, *.m4a, *.mp3)';
                                   '*.*','All Files (*.*)'}, 'Select audio file(s)', 'MultiSelect', 'on');
        if isequal(names, 0)
            fprintf('No files selected. Exiting.\n');
            return;
        end
        if ischar(names)
            filePaths = {fullfile(path, names)}; %#ok<ISCHART> % single selection
        else
            filePaths = cellfun(@(n) fullfile(path, n), names, 'UniformOutput', false);
        end
    elseif ischar(filePaths)
        filePaths = {filePaths}; %#ok<ISCHART>
    end

    outputDir = fullfile(pwd, 'processed');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    processedSignals = {};
    processedSampleRates = [];
    processedFileLabels = {};

    targetFs = 16000;

    for idx = 1:numel(filePaths)
        inFile = filePaths{idx};
        try
            [signal, fs] = audioread(inFile);
        catch readErr
            fprintf('Failed to read %s: %s\n', inFile, readErr.message);
            continue;
        end

        if isempty(signal)
            fprintf('File %s seems empty. Skipping.\n', inFile);
            continue;
        end

        % Convert to mono if stereo
        if size(signal, 2) == 2
            monoSignal = mean(signal, 2);
        else
            monoSignal = signal(:, 1);
        end

        % Simple listen check
        fprintf('Playing cleaned mono from %s at %d Hz...\n', inFile, fs);
        try
            sound(monoSignal, fs);
            pause(min(3, numel(monoSignal)/fs)); % preview up to 3 seconds
        catch
            % playback may fail on some systems; continue processing
        end

        % Write cleaned mono (original sample rate)
        [~, baseName, ~] = fileparts(inFile);
        cleanedOut = fullfile(outputDir, sprintf('%s_mono.wav', baseName));
        try
            audiowrite(cleanedOut, monoSignal, fs);
            fprintf('Wrote cleaned mono: %s\n', cleanedOut);
        catch writeErr
            fprintf('Failed to write %s: %s\n', cleanedOut, writeErr.message);
        end

        % Resample to 16 kHz if appropriate
        if fs < targetFs
            fprintf(['WARNING: Original sampling rate %d Hz is lower than %d Hz. '\n ...
                     'It is recommended to re-record at a higher rate and repeat. Skipping resample.\n'], fs, targetFs);
            processedSignal = monoSignal;
            processedFs = fs;
            resampledOut = '';
        elseif fs ~= targetFs
            try
                processedSignal = resample(monoSignal, targetFs, fs);
                processedFs = targetFs;
                resampledOut = fullfile(outputDir, sprintf('%s_mono_16k.wav', baseName));
                audiowrite(resampledOut, processedSignal, processedFs);
                fprintf('Resampled to 16 kHz and wrote: %s\n', resampledOut);
            catch rsErr
                fprintf('Resample failed for %s: %s\n', inFile, rsErr.message);
                processedSignal = monoSignal;
                processedFs = fs;
                resampledOut = '';
            end
        else
            processedSignal = monoSignal;
            processedFs = fs;
            resampledOut = cleanedOut;
        end

        processedSignals{end+1} = processedSignal; %#ok<AGROW>
        processedSampleRates(end+1) = processedFs; %#ok<AGROW>
        processedFileLabels{end+1} = ~isempty(resampledOut) * string(resampledOut) + isempty(resampledOut) * string(cleanedOut); %#ok<AGROW>
    end

    if isempty(processedSignals)
        fprintf('No files processed successfully.\n');
        return;
    end

    % Plot waveform (sample index vs amplitude) for the first processed file
    firstSignal = processedSignals{1};
    firstFs = processedSampleRates(1);
    figure('Name', 'Waveform (Sample Index vs Amplitude)');
    plot(1:numel(firstSignal), firstSignal, 'LineWidth', 1);
    grid on;
    xlabel('Sample Index');
    ylabel('Amplitude');
    title('Processed Audio Waveform');

    % Generate 1 kHz cosine matching length and duration of the processed signal
    durationSeconds = numel(firstSignal) / firstFs;
    cosineFs = firstFs; % match sampling rate of processed audio
    numSamples = numel(firstSignal);
    t = (0:numSamples-1).' / cosineFs;
    cosineFreqHz = 1000; % 1 kHz
    cosineSignal = cos(2*pi*cosineFreqHz*t);

    % Playback generated cosine
    fprintf('Playing 1 kHz cosine (%.3f s) at %d Hz...\n', durationSeconds, cosineFs);
    try
        sound(cosineSignal, cosineFs);
        pause(min(3, durationSeconds));
    catch
    end

    % Plot two cycles of 1 kHz cosine vs time
    twoCyclesDuration = 2 / cosineFreqHz; % 2 ms for 1 kHz
    twoCyclesSamples = max(1, round(twoCyclesDuration * cosineFs));
    figure('Name', '1 kHz Cosine - Two Cycles');
    plot(t(1:twoCyclesSamples)*1e3, cosineSignal(1:twoCyclesSamples), 'LineWidth', 1.5);
    grid on;
    xlabel('Time (ms)');
    ylabel('Amplitude');
    title('Two Cycles of 1 kHz Cosine');

    % Save generated cosine to disk matching first processed label
    firstLabel = char(processedFileLabels{1});
    [~, baseFirst, ~] = fileparts(firstLabel);
    cosineOut = fullfile(outputDir, sprintf('%s_cosine1k.wav', baseFirst));
    try
        audiowrite(cosineOut, cosineSignal, cosineFs);
        fprintf('Wrote 1 kHz cosine: %s\n', cosineOut);
    catch writeErr
        fprintf('Failed to write cosine: %s\n', writeErr.message);
    end
end


