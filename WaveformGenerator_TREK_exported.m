classdef WaveformGenerator_TREK_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        VVLabel                         matlab.ui.control.Label
        VoltagecalibrationconstantEditField  matlab.ui.control.NumericEditField
        VoltagecalibrationconstantLabel  matlab.ui.control.Label
        msLabel                         matlab.ui.control.Label
        RamptimeEditField               matlab.ui.control.NumericEditField
        RamptimeEditFieldLabel          matlab.ui.control.Label
        HzLabel_2                       matlab.ui.control.Label
        HzLabel                         matlab.ui.control.Label
        kVLabel                         matlab.ui.control.Label
        GoButton                        matlab.ui.control.StateButton
        SamplerateEditField             matlab.ui.control.NumericEditField
        SamplerateEditFieldLabel        matlab.ui.control.Label
        FrequencyEditField              matlab.ui.control.NumericEditField
        FrequencyEditFieldLabel         matlab.ui.control.Label
        MaxvoltageEditField             matlab.ui.control.NumericEditField
        MaxvoltageEditFieldLabel        matlab.ui.control.Label
        NumberofcyclesEditField         matlab.ui.control.NumericEditField
        NumberofcyclesEditFieldLabel    matlab.ui.control.Label
        ReversevoltagepolarityCheckBox  matlab.ui.control.CheckBox
        SignaltypeDropDown              matlab.ui.control.DropDown
        SignaltypeDropDownLabel         matlab.ui.control.Label
        DAQconnectionsAO0VoltagesignalPFI0LimittripLabel  matlab.ui.control.Label
        SignaloutputDropDown            matlab.ui.control.DropDown
        SignaloutputDropDownLabel       matlab.ui.control.Label
        UIAxes                          matlab.ui.control.UIAxes
    end

    % Author: Zachary Yoder
    % Created: March 2020
    % Last updated: 21 October 2024
    % Notes: Added DAQ selection function

    properties (Access = private)
        voltage_constant; % kVtrek/Vdaq
        max_voltage
        d;
        dev_name;
        sample_rate;
        output_signal;
    end
    
    methods (Access = private)
        
        function PlotPreview(app)
            if app.FrequencyEditField.Value == 0 || app.NumberofcyclesEditField.Value == 0
                return
            end
            
            % Build time axis
            x = linspace(0, length(app.output_signal)/app.sample_rate, length(app.output_signal));
            
            % Plot signal
            plot(app.UIAxes, x, app.output_signal); % s, V

            app.UIAxes.YLim = [-app.max_voltage - 1, app.max_voltage + 1];
        end
        
        function BuildFullSignal(app, single_cycle, num_cycles)

            % Initialize empty vector
            app.output_signal = zeros(num_cycles*length(single_cycle), 1);
            % Populate single cycle
            app.output_signal(1: length(single_cycle), 1) = single_cycle;
            
            % Repeat specified number of single cycles
            for i = 1:num_cycles - 1
                j = i*length(single_cycle);

                % Conditional - reverse polarity
                if app.ReversevoltagepolarityCheckBox.Value
                    single_cycle = -single_cycle;
                end
                app.output_signal(j + 1: j+length(single_cycle), 1) = single_cycle;
            end

            % Plot output signal preview
            PlotPreview(app)
        end
        
        function single_cycle = BuildSingleCycle(app)
            signal_type = app.SignaltypeDropDown.Value;
            frequency = app.FrequencyEditField.Value;
            
            if frequency == 0
                single_cycle = zeros(app.sample_rate, 1);
            else
                cycle_samples = round(app.sample_rate/frequency);
                    % Number of samples per one voltage cycle
                
                % Initialize empty vector
                single_cycle = zeros(cycle_samples, 1);

                % Build cycle based on user selection
                switch signal_type
                    case 'Square'
                        % 1/4 zero, 2/4 max voltage, 1/4 zero
                        idx_start = round(cycle_samples/4) + 1;
                        idx_end = round(cycle_samples*3/4);
                        single_cycle(idx_start: idx_end) = app.max_voltage;

                    case 'Ramped square'
                        % 1/4 zero, 2/4 max voltage, 1/4 zero
                        idx_start = round(cycle_samples/4) + 1;
                        idx_end = round(cycle_samples*3/4);
                        single_cycle(idx_start: idx_end) = app.max_voltage;

                        if app.RamptimeEditField.Value ~= 0
                            % Build ramp
                            num_samples_ramp = round(app.RamptimeEditField.Value/1000*app.sample_rate);
                            ramp = linspace(0, app.max_voltage, num_samples_ramp).';
    
                            % Add ramp up
                            idx_ramp_start = idx_start - round(num_samples_ramp/2);
                            idx_ramp_end = idx_ramp_start + num_samples_ramp - 1;
                            single_cycle(idx_ramp_start: idx_ramp_end, 1) = ramp;
    
                            % Add ramp down
                            idx_ramp_start = idx_end - round(num_samples_ramp/2);
                            idx_ramp_end = idx_ramp_start + num_samples_ramp - 1;
                            single_cycle(idx_ramp_start: idx_ramp_end, 1) = flip(ramp);
                        end

                    case 'Sine'
                        single_cycle = (app.max_voltage/2).*(sin(linspace(-pi/2, (3*pi)/2, cycle_samples))+1);
                        single_cycle = transpose(single_cycle);
                    case 'Triangle'
                        single_cycle(1:cycle_samples/2, 1) = linspace(0, app.max_voltage, cycle_samples/2).';
                        single_cycle(cycle_samples/2 + 1: end, 1) = linspace(app.max_voltage, 0, cycle_samples/2).';
                    case 'Constant DC'
                        single_cycle(1:end, 1) = app.max_voltage;
                end
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Collect startup values
            app.voltage_constant = app.VoltagecalibrationconstantEditField.Value/1000; % [kV/V]
                % Voltage calibration constant, in kV/V throughout the program
            app.max_voltage = app.MaxvoltageEditField.Value/app.voltage_constant; % [V]
                % Max voltage output by the DAQ
            app.NumberofcyclesEditField.Enable = 'off';
            app.sample_rate = app.SamplerateEditField.Value;
            app.RamptimeEditField.Enable = 0;

            % Initialize preview
            BuildFullSignal(app, BuildSingleCycle(app), 0);

            % Select and connect to DAQ
            available_daqs = daqlist;
            if isempty(available_daqs)
                uiwait(msgbox("No DAQ selected, preview mode only", "Error", 'modal'));
                app.GoButton.Enable = 0;
            else
                [idx, ~] = listdlg('PromptString', 'Select a device.', ...
                    'SelectionMode', 'single', 'ListString', available_daqs.Model);
                app.d = daq("ni");
                app.d.Rate = app.sample_rate;
                app.dev_name = available_daqs.DeviceID(idx);
    
                % Add voltage output
                addoutput(app.d, app.dev_name, "ao0", "Voltage");
            end
        end

        % Value changed function: GoButton
        function GoButtonValueChanged(app, event)
            % Go button pressed
            if app.GoButton.Value

                % Change button appearance
                app.GoButton.Text = "Stop";
                app.GoButton.BackgroundColor = 'red';
                
                % Conditional - continuous or set number of cycles
                signal_output = app.SignaloutputDropDown.Value;

                % Continuous case
                if strcmp(signal_output, 'Continuous')

                    % Build output signal in function BuildFullSignal with default 2 cycles
                    num_cycles = 2;
                    BuildFullSignal(app, BuildSingleCycle(app), num_cycles);
                    
                    % Ensure we are preloading enough data - DAQ can be unhappy with very short vectors
                    while length(app.output_signal) < round(app.sample_rate/2)
                        num_cycles = num_cycles + 2;
                        BuildFullSignal(app, BuildSingleCycle(app), num_cycles);
                    end
                    
                    % Preload vector and start repeat output
                    % Output continues until interrupted
                    preload(app.d, app.output_signal);
                    start(app.d, "RepeatOutput");

                % Set number case
                else

                    % Check for zero cycles (is this needed?)
                    if app.NumberofcyclesEditField.Value == 0
                        uiwait(msgbox("Number of cycles set to 0", "Error", 'modal'));
                        app.GoButton.Value = 0;
                        app.GoButton.Text = "Go";
                        app.GoButton.BackgroundColor = 'green';
                        return
                    end

                    % Build output signal in function BuildFullSignal with specified number of cycles
                    BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);

                    % Ensure we are preloading enough data - DAQ can be unhappy with very short vectors
                    % Pad with zeros if needed
                    if length(app.output_signal) < round(app.sample_rate/2)
                        zeroVector = zeros(round(app.sample_rate/2) - length(app.output_signal), 1);
                        app.output_signal = [app.output_signal; zeroVector];
                    end

                    % Ensure last element is zero
                    app.output_signal(end, 1) = 0;
                    
                    % Preload vector and start output
                    % Output continues for full vector
                    preload(app.d, app.output_signal);
                    start(app.d);
                end

            % Stop button pressed
            else

                % Stop DAQ execution and ensure 0 V output
                if app.d.Running
                    stop(app.d);
                    write(app.d, 0);
                end
                
                % Change button appearance
                app.GoButton.Text = "Go";
                app.GoButton.BackgroundColor = 'green';
            end
        end

        % Value changed function: SignaloutputDropDown
        function SignaloutputDropDownValueChanged(app, event)
            if strcmp(app.SignaloutputDropDown.Value, 'Set number')
                app.NumberofcyclesEditField.Enable = 'on';
            else
                app.NumberofcyclesEditField.Enable = 'off';
                app.NumberofcyclesEditField.Value = 2;
            end
            
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: MaxvoltageEditField
        function MaxvoltageEditFieldValueChanged(app, event)
            app.max_voltage = app.MaxvoltageEditField.Value/app.voltage_constant;
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: FrequencyEditField
        function FrequencyEditFieldValueChanged(app, event)
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: SignaltypeDropDown
        function SignaltypeDropDownValueChanged(app, event)
            if strcmp(app.SignaltypeDropDown.Value, 'Ramped square')
                app.RamptimeEditField.Enable = 1;
            else
                app.RamptimeEditField.Enable = 0;
            end

            if strcmp(app.SignaltypeDropDown.Value, 'Constant DC')
                app.ReversevoltagepolarityCheckBox.Value = 0;
                app.ReversevoltagepolarityCheckBox.Enable = 0;

                app.FrequencyEditField.Value = 1;
                app.FrequencyEditField.Enable = 0;
            else
                app.ReversevoltagepolarityCheckBox.Enable = 1;
                app.FrequencyEditField.Enable = 1;
            end
            
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: ReversevoltagepolarityCheckBox
        function ReversevoltagepolarityCheckBoxValueChanged(app, event)
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: SamplerateEditField
        function SamplerateEditFieldValueChanged(app, event)
            app.sample_rate = app.SamplerateEditField.Value;
            app.d.Rate = app.sample_rate;

            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: RamptimeEditField
        function RamptimeEditFieldValueChanged(app, event)
            if app.RamptimeEditField.Value > (1/(app.FrequencyEditField.Value*2)*1000)
                uiwait(msgbox("Ramp time too long for selected frequency", "Error", 'modal'));
                app.RamptimeEditField.Value = 0;
            end
            
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: NumberofcyclesEditField
        function NumberofcyclesEditFieldValueChanged(app, event)
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end

        % Value changed function: VoltagecalibrationconstantEditField
        function VoltagecalibrationconstantEditFieldValueChanged(app, event)
            app.voltage_constant = app.VoltagecalibrationconstantEditField.Value/1000;
            app.max_voltage = app.MaxvoltageEditField.Value/app.voltage_constant;
            BuildFullSignal(app, BuildSingleCycle(app), app.NumberofcyclesEditField.Value);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 490 457];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Waveform preview')
            xlabel(app.UIAxes, 'Time [s]')
            ylabel(app.UIAxes, 'Output voltage [V]')
            app.UIAxes.PlotBoxAspectRatio = [1.45813953488372 1 1];
            app.UIAxes.FontWeight = 'bold';
            app.UIAxes.XTickLabelRotation = 0;
            app.UIAxes.YTickLabelRotation = 0;
            app.UIAxes.ZTickLabelRotation = 0;
            app.UIAxes.Box = 'on';
            app.UIAxes.Position = [12 190 325 258];

            % Create SignaloutputDropDownLabel
            app.SignaloutputDropDownLabel = uilabel(app.UIFigure);
            app.SignaloutputDropDownLabel.HorizontalAlignment = 'right';
            app.SignaloutputDropDownLabel.Position = [40 50 79 22];
            app.SignaloutputDropDownLabel.Text = 'Signal output';

            % Create SignaloutputDropDown
            app.SignaloutputDropDown = uidropdown(app.UIFigure);
            app.SignaloutputDropDown.Items = {'Continuous', 'Set number'};
            app.SignaloutputDropDown.ValueChangedFcn = createCallbackFcn(app, @SignaloutputDropDownValueChanged, true);
            app.SignaloutputDropDown.Position = [131 50 121 22];
            app.SignaloutputDropDown.Value = 'Continuous';

            % Create DAQconnectionsAO0VoltagesignalPFI0LimittripLabel
            app.DAQconnectionsAO0VoltagesignalPFI0LimittripLabel = uilabel(app.UIFigure);
            app.DAQconnectionsAO0VoltagesignalPFI0LimittripLabel.FontWeight = 'bold';
            app.DAQconnectionsAO0VoltagesignalPFI0LimittripLabel.Position = [350 246 126 59];
            app.DAQconnectionsAO0VoltagesignalPFI0LimittripLabel.Text = {'DAQ connections:'; ''; 'AO0: voltage input to'; 'amplifier'};

            % Create SignaltypeDropDownLabel
            app.SignaltypeDropDownLabel = uilabel(app.UIFigure);
            app.SignaltypeDropDownLabel.HorizontalAlignment = 'right';
            app.SignaltypeDropDownLabel.Position = [49 113 67 22];
            app.SignaltypeDropDownLabel.Text = 'Signal type';

            % Create SignaltypeDropDown
            app.SignaltypeDropDown = uidropdown(app.UIFigure);
            app.SignaltypeDropDown.Items = {'Square', 'Ramped square', 'Sine', 'Triangle', 'Constant DC'};
            app.SignaltypeDropDown.ValueChangedFcn = createCallbackFcn(app, @SignaltypeDropDownValueChanged, true);
            app.SignaltypeDropDown.Position = [131 113 121 22];
            app.SignaltypeDropDown.Value = 'Square';

            % Create ReversevoltagepolarityCheckBox
            app.ReversevoltagepolarityCheckBox = uicheckbox(app.UIFigure);
            app.ReversevoltagepolarityCheckBox.ValueChangedFcn = createCallbackFcn(app, @ReversevoltagepolarityCheckBoxValueChanged, true);
            app.ReversevoltagepolarityCheckBox.Text = 'Reverse voltage polarity';
            app.ReversevoltagepolarityCheckBox.Position = [295 18 151 22];

            % Create NumberofcyclesEditFieldLabel
            app.NumberofcyclesEditFieldLabel = uilabel(app.UIFigure);
            app.NumberofcyclesEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofcyclesEditFieldLabel.Position = [16 18 102 22];
            app.NumberofcyclesEditFieldLabel.Text = 'Number of cycles';

            % Create NumberofcyclesEditField
            app.NumberofcyclesEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumberofcyclesEditField.Limits = [0 Inf];
            app.NumberofcyclesEditField.RoundFractionalValues = 'on';
            app.NumberofcyclesEditField.ValueChangedFcn = createCallbackFcn(app, @NumberofcyclesEditFieldValueChanged, true);
            app.NumberofcyclesEditField.Position = [131 18 85 22];
            app.NumberofcyclesEditField.Value = 2;

            % Create MaxvoltageEditFieldLabel
            app.MaxvoltageEditFieldLabel = uilabel(app.UIFigure);
            app.MaxvoltageEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxvoltageEditFieldLabel.Position = [281 113 70 22];
            app.MaxvoltageEditFieldLabel.Text = 'Max voltage';

            % Create MaxvoltageEditField
            app.MaxvoltageEditField = uieditfield(app.UIFigure, 'numeric');
            app.MaxvoltageEditField.Limits = [0 20];
            app.MaxvoltageEditField.ValueChangedFcn = createCallbackFcn(app, @MaxvoltageEditFieldValueChanged, true);
            app.MaxvoltageEditField.Position = [367 113 60 22];

            % Create FrequencyEditFieldLabel
            app.FrequencyEditFieldLabel = uilabel(app.UIFigure);
            app.FrequencyEditFieldLabel.HorizontalAlignment = 'right';
            app.FrequencyEditFieldLabel.Position = [289 81 62 22];
            app.FrequencyEditFieldLabel.Text = 'Frequency';

            % Create FrequencyEditField
            app.FrequencyEditField = uieditfield(app.UIFigure, 'numeric');
            app.FrequencyEditField.Limits = [0 Inf];
            app.FrequencyEditField.ValueChangedFcn = createCallbackFcn(app, @FrequencyEditFieldValueChanged, true);
            app.FrequencyEditField.Position = [367 81 60 22];

            % Create SamplerateEditFieldLabel
            app.SamplerateEditFieldLabel = uilabel(app.UIFigure);
            app.SamplerateEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplerateEditFieldLabel.Position = [279 50 74 22];
            app.SamplerateEditFieldLabel.Text = 'Sample rate';

            % Create SamplerateEditField
            app.SamplerateEditField = uieditfield(app.UIFigure, 'numeric');
            app.SamplerateEditField.Limits = [0 Inf];
            app.SamplerateEditField.RoundFractionalValues = 'on';
            app.SamplerateEditField.ValueChangedFcn = createCallbackFcn(app, @SamplerateEditFieldValueChanged, true);
            app.SamplerateEditField.Position = [367 50 60 22];
            app.SamplerateEditField.Value = 10000;

            % Create GoButton
            app.GoButton = uibutton(app.UIFigure, 'state');
            app.GoButton.ValueChangedFcn = createCallbackFcn(app, @GoButtonValueChanged, true);
            app.GoButton.Text = 'Go';
            app.GoButton.BackgroundColor = [0 1 0];
            app.GoButton.FontSize = 24;
            app.GoButton.FontWeight = 'bold';
            app.GoButton.Position = [358 328 102 64];

            % Create kVLabel
            app.kVLabel = uilabel(app.UIFigure);
            app.kVLabel.Position = [435 113 25 22];
            app.kVLabel.Text = 'kV';

            % Create HzLabel
            app.HzLabel = uilabel(app.UIFigure);
            app.HzLabel.Position = [435 81 25 22];
            app.HzLabel.Text = 'Hz';

            % Create HzLabel_2
            app.HzLabel_2 = uilabel(app.UIFigure);
            app.HzLabel_2.Position = [435 50 25 22];
            app.HzLabel_2.Text = 'Hz';

            % Create RamptimeEditFieldLabel
            app.RamptimeEditFieldLabel = uilabel(app.UIFigure);
            app.RamptimeEditFieldLabel.HorizontalAlignment = 'right';
            app.RamptimeEditFieldLabel.Position = [49 81 64 22];
            app.RamptimeEditFieldLabel.Text = 'Ramp time';

            % Create RamptimeEditField
            app.RamptimeEditField = uieditfield(app.UIFigure, 'numeric');
            app.RamptimeEditField.ValueChangedFcn = createCallbackFcn(app, @RamptimeEditFieldValueChanged, true);
            app.RamptimeEditField.Position = [131 81 85 22];

            % Create msLabel
            app.msLabel = uilabel(app.UIFigure);
            app.msLabel.Position = [227 81 25 22];
            app.msLabel.Text = 'ms';

            % Create VoltagecalibrationconstantLabel
            app.VoltagecalibrationconstantLabel = uilabel(app.UIFigure);
            app.VoltagecalibrationconstantLabel.HorizontalAlignment = 'right';
            app.VoltagecalibrationconstantLabel.FontWeight = 'bold';
            app.VoltagecalibrationconstantLabel.Position = [126 156 165 22];
            app.VoltagecalibrationconstantLabel.Text = 'Voltage calibration constant';

            % Create VoltagecalibrationconstantEditField
            app.VoltagecalibrationconstantEditField = uieditfield(app.UIFigure, 'numeric');
            app.VoltagecalibrationconstantEditField.ValueChangedFcn = createCallbackFcn(app, @VoltagecalibrationconstantEditFieldValueChanged, true);
            app.VoltagecalibrationconstantEditField.FontWeight = 'bold';
            app.VoltagecalibrationconstantEditField.Position = [306 156 60 22];
            app.VoltagecalibrationconstantEditField.Value = 1000;

            % Create VVLabel
            app.VVLabel = uilabel(app.UIFigure);
            app.VVLabel.FontWeight = 'bold';
            app.VVLabel.Position = [374 156 25 22];
            app.VVLabel.Text = 'V/V';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = WaveformGenerator_TREK_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end