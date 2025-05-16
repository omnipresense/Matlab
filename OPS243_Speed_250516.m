% Live Serial Plot with Logging and Unit Detection (No Buttons)

% ---- User Configuration ----
portName = 'COM4';
baudRate = 19200;
% ----------------------------

% Timestamped filenames
timestampStr = datestr(now, 'yyyy_mm_dd_HHMM');
logFilename = sprintf('speed_log_%s.csv', timestampStr);
plotFilename = sprintf('speed_plot_%s.png', timestampStr);

% Initialize serial port
s = serial(portName, 'BaudRate', baudRate, 'Terminator', 'LF', 'Timeout', 10);
fopen(s);

% Send initialization commands
fprintf("Sending startup commands (OT, OJ, OU)...\n");
fprintf(s, 'OT\n');
pause(0.1);
fprintf(s, 'OJ\n');
pause(0.1);
fprintf(s, 'OU\n');
pause(0.1);
fprintf("Startup commands sent. Listening for data...\n");

% Open log file
fid = fopen(logFilename, 'w');
fprintf(fid, "time,unit,speed\n");

% Data storage
timeVals = [];
speedVals = [];
speedUnit = '';

% Create GUI figure for plotting
fig = figure('Name', 'Live Speed Plot', 'Position', [100, 100, 800, 500]);

% Plot setup
hAxes = axes('Parent', fig, 'Position', [0.1, 0.3, 0.85, 0.65]);
hPlot = plot(NaN, NaN, '-o');
xlabel('Time (s)');
ylabel('Speed');
title('Live Speed vs Time');
grid on;

% Clean-up handler
cleanup = onCleanup(@() stopLogging(fid, s, timeVals, speedVals, plotFilename));

% Main data loop
while ishandle(fig)
    try
        if isvalid(s) && s.BytesAvailable > 0
            rawLine = strtrim(fgetl(s));

            if isempty(rawLine)
                continue;
            end

            try
                jsonData = jsondecode(rawLine);
            catch
                warning('Invalid JSON: %s', rawLine);
                continue;
            end

            % Extract and process data
            if isfield(jsonData, 'time') && isfield(jsonData, 'speed') && isfield(jsonData, 'unit')
                t = str2double(jsonData.time);
                v = str2double(jsonData.speed);
                unit = strtrim(jsonData.unit);

                if ~isnan(t) && ~isnan(v)
                    timeVals(end+1) = t;
                    speedVals(end+1) = v;

                    % Log to file
                    fprintf(fid, "%.3f,%s,%.3f\n", t, unit, v);

                    % Update axis label if unit changed
                    if ~strcmp(speedUnit, unit)
                        speedUnit = unit;
                        switch unit
                            case 'mps'
                                ylabel('Speed (m/s)');
                            case 'mph'
                                ylabel('Speed (m/hr)');
                            case 'kmh'
                                ylabel('Speed (km/hr)');
                            otherwise
                                ylabel('Speed');
                        end
                    end

                    % Update plot
                    set(hPlot, 'XData', timeVals, 'YData', speedVals);
                    ylim('auto');
                    drawnow limitrate;
                end
            end
        end
    catch err
        warning('Loop Error: %s', err.message);
    end
end

% -------- Cleanup --------
function stopLogging(fid, s, timeVals, speedVals, plotFilename)
    fprintf("\nStopping data collection...\n");
    fclose(fid);
    if isvalid(s)
        fclose(s);
        delete(s);
    end
    clear s;
    if ~isempty(timeVals)
        saveas(gcf, plotFilename);
        fprintf("Plot saved to %s\n", plotFilename);
    end
end
