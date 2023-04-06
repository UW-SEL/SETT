% Real Gas Properties using REFPROP

classdef RealGasRefprop
    properties (Constant)
        defaultParams = struct(  ...
            "name", "Hydrogen"   ...
        )
    end

    methods(Static)
        props = refprop(T, P)
    end

    methods
        function obj = RealGasRefprop(params)
            clear refprop;  % necessary because refprop.mexw64 has state that must be reinitialized
            obj.refprop(params.name);
        end

        function r = allProps(obj, T, P)
            props = obj.refprop(T, P);
            r.drho_dT_P = props.dDdT_P;
            r.drho_dP_T = props.dDdP_T;
            r.rho = props.dens;
            r.h = props.enth;
            r.u = props.inte;
            r.du_dT_P = props.dudT_P;
            r.du_dP_T = props.dudP_T;
            r.CP = props.cp;
            r.k = props.cond;
            r.mu = props.visc;
        end

        function r = density(obj, T, P)
            props = obj.refprop(T, P);
            r = props.dens;
        end

        function r = enthalpy(obj, T, P)
            props = obj.refprop(T, P);
            r = props.enth;
        end
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            gridLayout.ColumnWidth = {"fit"};
            gridLayout.RowHeight = {"fit"};
            fluids = ["Argon", "CarbonDioxide", "Helium", "Hydrogen"];
            nameDropdown = uidropdown(  ...
                gridLayout,             ...
                "Items", fluids,        ...
                "Value", params.name    ...
            );

            getParams = @getParamsFunc;
            function r = getParamsFunc()
                r = struct("name", nameDropdown.Value);
            end
        end
    end
end

