function exportToSimulink(obj, options)
    % EXPORTTOSIMULINK Generate a curve-based model for use in Simulink
    %
    % TODO: Add descriptions of all arguments here
    arguments
        obj
        options.minSpeed (1,1) {mustBeNumeric}   % rpm
        options.maxSpeed (1,1) {mustBeNumeric}   % rpm
        options.numSpeed (1,1) {mustBeNumeric, mustBeGreaterThan(options.numSpeed,1)}
        options.minPressure (1,1) {mustBeNumeric}   % Pa
        options.maxPressure (1,1) {mustBeNumeric}   % Pa
        options.numPressure (1,1) {mustBeNumeric, mustBeGreaterThan(options.numPressure,1)}
        options.file string = ""
        options.numCylinders (1,1) {mustBeNumeric, mustBePositive} = 1
    end

    % Check that all required arguments are present
    if isempty(options.minSpeed); error("minSpeed is required"); end
    if isempty(options.maxSpeed); error("maxSpeed is required"); end
    if isempty(options.numSpeed); error("numSpeed is required"); end
    if isempty(options.minPressure); error("minPressure is required"); end
    if isempty(options.maxPressure); error("maxPressure is required"); end
    if isempty(options.numPressure); error("numPressure is required"); end
    if options.file == ""; error("file is required"); end

    % Generate speed and pressure breakpoints
    speeds = linspace(options.minSpeed, options.maxSpeed, options.numSpeed);
    pressures = linspace(options.minPressure, options.maxPressure, options.numPressure);

    % Initialize results arrays
    torqueValues = zeros(options.numSpeed, options.numPressure);
    heatInputValues = zeros(options.numSpeed, options.numPressure);
    heatRejectionValues = zeros(options.numSpeed, options.numPressure);
    electricInputValues = zeros(options.numSpeed, options.numPressure);

    % Fill results arrays
    currentRun = 1;
    totalRuns = options.numSpeed * options.numPressure;
    for j = 1:numel(pressures)
        P_0 = pressures(j);
        for i = 1:numel(speeds)
            N = speeds(i);
            fprintf("%g rpm at %g Pa (run %i of %i)\n", N, P_0, currentRun, totalRuns)
            obj.updateParams('ws.frequency', N / 60);
            obj.run('P_0', P_0);
            torqueValues(i, j) = obj.shaftTorque;
            heatInputValues(i, j) = obj.heatInput;
            heatRejectionValues(i, j) = obj.heatRejection;
            electricInputValues(i, j) = obj.chx.W_parasitic + obj.hhx.W_parasitic; % aux electric power
            currentRun = currentRun + 1;
        end
    end

    % Save all required Simulink variables to a .mat file

    seSpeedBreakpoints = Simulink.Breakpoint;
    seSpeedBreakpoints.Breakpoints.Value = speeds;
    seMinSpeed = options.minSpeed;
    seMaxSpeed = options.maxSpeed;

    sePressureBreakpoints = Simulink.Breakpoint;
    sePressureBreakpoints.Breakpoints.Value = pressures;
    seMinPressure = options.minPressure;
    seMaxPressure = options.maxPressure;

    seTorqueTable = Simulink.LookupTable;
    seTorqueTable.Table.Value = torqueValues * options.numCylinders;
    seTorqueTable.BreakpointsSpecification = "Reference";
    seTorqueTable.Breakpoints = {"seSpeedBreakpoints", "sePressureBreakpoints"};
    seTorqueTable.StructTypeInfo.Name = "seTorqueTable";

    seHeatInputTable = Simulink.LookupTable;
    seHeatInputTable.Table.Value = heatInputValues * options.numCylinders;
    seHeatInputTable.BreakpointsSpecification = "Reference";
    seHeatInputTable.Breakpoints = {"seSpeedBreakpoints", "sePressureBreakpoints"};
    seHeatInputTable.StructTypeInfo.Name = "seHeatInputTable";

    seHeatRejectionTable = Simulink.LookupTable;
    seHeatRejectionTable.Table.Value = heatRejectionValues * options.numCylinders;
    seHeatRejectionTable.BreakpointsSpecification = "Reference";
    seHeatRejectionTable.Breakpoints = {"seSpeedBreakpoints", "sePressureBreakpoints"};
    seHeatRejectionTable.StructTypeInfo.Name = "seHeatRejectionTable";

    seElectricInputTable = Simulink.LookupTable;
    seElectricInputTable.Table.Value = electricInputValues * options.numCylinders;
    seElectricInputTable.BreakpointsSpecification = "Reference";
    seElectricInputTable.Breakpoints = {"seSpeedBreakpoints", "sePressureBreakpoints"};
    seElectricInputTable.StructTypeInfo.Name = "seElectricInputTable";

    save(                         ...
        options.file,             ...
        'seSpeedBreakpoints',     ...
        'sePressureBreakpoints',  ...
        'seTorqueTable',          ...
        'seHeatInputTable',       ...
        'seHeatRejectionTable',   ...
        'seElectricInputTable',   ...
        'seMinSpeed',             ...
        'seMaxSpeed',             ...
        'seMinPressure',          ...
        'seMaxPressure'           ...
    )
end


