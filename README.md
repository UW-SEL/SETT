# SETT

## Description

**SETT** is a Stirling engine modeling tool written in MATLAB.

## Getting Started

The easiest way to get started with the tool is to create an engine config JSON file using the GUI.  To do this, change to the main project directory in MATLAB, which contains (among other things) the `@StirlingEngine` class folder and the `+components` package folder.

To open the GUI, run:

```matlab
StirlingEngineApp
```

Step through each tab and select which component models to use and configure their parameters.  The `Solver` tab allows you to specify options related to solving for the cyclic steady state of the engine.  The `Conditions` tab is where you define the operating conditions of the cycle.

Once the engine is configured, click the green triangle icon in the toobar to run the engine.  When the engine is running a residuals plot will appear.  After a successful run, the residual plot title will change to "Run Finished" and the time required to solve the engine is shown.

When you are satisfied with the configuration of the engine, click the save icon in the toolbar.  The program will ask you where to save the JSON file that defines this engine configuration.

Once you have an engine configuration file, it can be used directly in MATLAB.  To do so, run:

```matlab
engine = StirlingEngine('config.json');  % where config.json is the name of saved engine file
```

Once initialized, the engine can be run at different conditions:

```matlab
engine.run()  % run the engine at the saved conditions
engine.run('T_cold', 310)  % run the engine with a new T_cold temperature (other conditions are unchanged)
engine.run('P_0', 11e6, 'T_hot', 1900)  % run the engine with a new P_0 and T_hot
engine.run('ShowResiduals', true)  % plot residuals as the engine is running
```

The condition values that can be adjusted when calling `run()` are `T_cold`, `T_hot`, and `P_0`.  The optional `ShowResiduals` argument will open a figure window and plot the residuals as the engine is running.

Once the `engine` object has been run, a number of performance metrics are available as properties on the `engine` object:

```matlab
engine.indicatedPowerZeroDP  % [W] average working spaces net power (*P dV*) over a cycle, excluding pressure drop
engine.indicatedPower        % [W] average working spaces net power (*P dV*) over a cycle, including pressure drop
engine.shaftPower            % [W] engine `indicatedPower` less internal mechanical parasitics `W_parasitic_c` and `W_parasitic_e`
engine.netPower              % [W] engine `shaftPower` less heat exchanger mechanical parasitics
engine.heatRejection         % [W] engine heat rejection, including all thermal parasitics
engine.heatInput             % [W] required engine heat input, including all thermal parasitics
engine.efficiency            % [-] engine `netPower` divided by `heatInput`
```

Various plots are available:

```matlab
engine.plot('ode-solution')
engine.plot('pv-diagram')
engine.plot('mass-flow')
engine.plot('temperature')
engine.plot('residuals')
```

Component parameters can be changed using:

```matlab
engine.updateParams('chx.R_hyd', 100)
```

Multiple changes can be specified with a single call to `updateParams()`:

```matlab
engine.updateParams('regen.geometry.mesh.pitch', 6000, 'hhx.W_parasitic', 1000)
```

If you would like to save the engine to a new config file after changing a component parameter or running at new conditions, use `engine.save()`.

## Code Organization

TODO: Add an overview of the folder and file organization

## Creating Component Models

Component models are MATLAB classes with a few required properties and methods.

TODO: Add information about each type of component and what requirements its class has.

Component models can optionally define a `report` method that is called when generating an engine report.  If this method is not defined, a generic report is written for that component.

## Acknowledgments

Initial work on this project was carried out through funding provided by the Army Research Lab through contract W911NF2020215.
