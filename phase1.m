% Directories
selectedDir = fullfile(pwd, 'Dataset', 'selected');
outputDir = fullfile(pwd, 'Dataset','processed');
cosineDir = fullfile(pwd, 'Dataset', 'processed', 'cosine');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
if ~exist(cosineDir, 'dir')
    mkdir(cosineDir);
end

% Parameters
validExts = {'.wav', '.m4a', '.mp3'};
targetFs = 16000; % Hz
playAudio = false; % set to true to listen to cleaned mono audio
playCosine = false;
playDuration = 5; % seconds to play cleaned audio (max 5s)

% Variables
files = getFiles(selectedDir, validExts);
processedSignals = {};
processedFileLabels = {};

for fileIdx = 1:length(files)
    fprintf('Processing file %d of %d: %s\n', fileIdx, length(files), files{fileIdx});
    
    [processedSignal, processedLabel, success] = processAudio(files{fileIdx}, targetFs, outputDir, playAudio, playDuration);
    if ~success
        fprintf('Failed to process %s\n', files{fileIdx});
    else
        processedSignals{end+1} = processedSignal;
        processedFileLabels{end+1} = processedLabel;
    end
end

if isempty(processedSignals)
    fprintf('No files processed successfully.\n');
    return;
else
    fprintf('Processed %d files successfully.\n', numel(processedSignals));
end

for i = 1:length(processedFileLabels)
    fprintf('Plotting File %d of %d: %s\n', i, length(processedFileLabels), processedFileLabels{i});
    plotAudio(processedFileLabels{i});
    plotCosine(processedFileLabels{i}, playCosine, playDuration, cosineDir);
end


function fileList = getFiles(selectedDir, validExts)
    fileList = {};
    audioFiles = dir(fullfile(selectedDir, '*.*'));
    for k = 1:numel(audioFiles)
        [~, ~, ext] = fileparts(audioFiles(k).name);
        if any(strcmpi(ext, validExts)) && ~audioFiles(k).isdir
            fileList{end+1} = fullfile(selectedDir, audioFiles(k).name);
        end
    end

    if isempty(fileList)
        fprintf('No valid audio files found in %s\n', selectedDir);
    else
        fprintf('Found %d valid audio files in %s\n', numel(fileList), selectedDir);
        for i = 1:numel(fileList)
            fprintf('  %s\n', fileList{i});
        end
    end
end

function [processedSignal, processedFileLabel, success] = processAudio(filePath, targetFs, outputDir, playAudio, playDuration)
% phase1: Read, normalize (mono), optionally resample to 16 kHz, analyze, and generate signals.
% Usage:
%   phase1                 % prompts to select one or more audio files
%   phase1({"file1.wav", "file2.m4a"})
%
% This script/function will:
% - Load one or more audio files using audioread
% - Convert stereo to mono by averaging channels
% - Play and write a cleaned mono version to disk
% - Resample to 16 kHz if original fs >= 16000 and fs ~= 16000
% - Plot waveform (sample index vs amplitude) for the first processed file
% - Generate a 1 kHz cosine matching the processed signal length and duration
% - Play the cosine and plot two cycles versus time
    processedSignal = [];
    processedFileLabel = '';
    success = false;
    
    [~, baseName, ~] = fileparts(filePath);
    
    try
        [signal, fs] = audioread(filePath);
    catch readErr
        fprintf('Failed to read %s: %s\n', filePath, readErr.message);
        return;
    end

    if isempty(signal)
        fprintf('File %s seems empty. Skipping.\n', filePath);
        return;
    end

    % Convert to mono if stereo
    if size(signal, 2) == 2
        processedSignal = mean(signal, 2);
    else
        processedSignal = signal(:, 1);
    end
    
    % Resample to 16 kHz
    if fs < targetFs
        fprintf('Original Sample Rate is lower than %d kHz. Skipping resample.\n', targetFs/1000);
        return;
    elseif fs > targetFs
        fprintf('The original sampling rate of %s is %d Hz.\n Adjusting sampling rate to %d kHz\n', filePath, fs, targetFs/1000);
        try
            processedSignal = resample(processedSignal, targetFs, fs);
            
            fprintf('Successfully resampled to 16 kHz\n');
        catch rsErr
            fprintf('Resample failed for %s: %s\n', filePath, rsErr.message);
            return;
        end
    else
        fprintf('The original sampling rate of %s is already %d kHz. No resampling needed.\n', filePath, fs/1000);
    end

    processedFs = targetFs;

    % Simple listen check
    if playAudio
        playTime = min(playDuration, numel(processedSignal)/processedFs); % play up to specified duration
        fprintf('Playing cleaned mono audio for %.1fs from %s at %d Hz...\n', playTime, filePath, processedFs);
        try
            sound(processedSignal, processedFs);
            pause(playTime); % pause for up to specified duration or full duration
        catch
            fprintf('Audio playback failed. Continuing processing...\n');
        end
    end

    processedOut = fullfile(outputDir, sprintf('%s_mono_16k.wav', baseName));
    audiowrite(processedOut, processedSignal, processedFs);
    fprintf('Wrote cleaned mono audio: %s\n', processedOut);

    success = true;
    processedFileLabel = processedOut;
end

function cosineSignal = plotCosine(filePath, playCosine, playDuration, cosineDir)
    [signal, fs] = audioread(filePath);
    [~, name, ~] = fileparts(filePath);

    samples = numel(signal);
    fprintf('Generating 1 kHz cosine matching length of %s at %d Hz (%d samples)...\n', name, fs, samples);
    t = (0:samples-1).' / fs;
    cosineFreqHz = 1000; % 1 kHz

    cosineSignal = cos(2*pi*cosineFreqHz*t);

    if playCosine
        playTime = min(playDuration, numel(cosineSignal)/fs); % play up to specified duration
        fprintf('Playing 1 kHz cosine (%.3f s) at %d Hz...\n', playTime, fs);
        try
            sound(cosineSignal, fs);
            pause(playTime); % wait for full playback duration
        catch
            fprintf('Cosine playback failed. Continuing plotting...\n');
        end
    end

    % Plot two cycles of 1 kHz cosine vs time
    twoCyclesDuration = 2 / cosineFreqHz; % 2 ms for 1 kHz
    twoCyclesSamples = max(1, round(twoCyclesDuration * fs));
    figure('Name', '1 kHz Cosine - Two Cycles');
    plot(t(1:twoCyclesSamples)*1e3, cosineSignal(1:twoCyclesSamples), 'LineWidth', 1.5);
    grid on;
    xlabel('Time (ms)');
    ylabel('Amplitude');
    title(sprintf('Two Cycles of 1 kHz Cosine for %s', name));

    % Save generated cosine to Dataset/processed/cosine directory
    [~, baseFirst, ~] = fileparts(filePath);
    cosineOut = fullfile(cosineDir, sprintf('%s_cosine1k.wav', baseFirst));
    try
        audiowrite(cosineOut, cosineSignal, fs);
        fprintf('Wrote 1 kHz cosine: %s\n', cosineOut);
    catch writeErr
        fprintf('Failed to write cosine: %s\n', writeErr.message);
    end
end

function plotAudio(filePath)
    [signal, fs] = audioread(filePath);
    [~, name, ~] = fileparts(filePath);
    % Plot waveform (sample index vs amplitude) for the first processed file
    fprintf('Plotting waveform for %s at %d Hz...\n', name, fs);
    figure('Name', sprintf('Waveform (Sample Index vs Amplitude) for %s', name));
    plot(1:numel(signal), signal, 'LineWidth', 1);
    grid on;
    xlabel('Sample Index');
    ylabel('Amplitude');
    title(sprintf('Processed Audio Waveform for %s', name));
end


