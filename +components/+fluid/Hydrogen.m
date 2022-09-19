% Ideal Gas Hydrogen with Corrections

classdef Hydrogen
    properties (Constant)
        defaultParams = struct
    end

    methods
        function obj = Hydrogen()
        end

        function r = allProps(obj, T, P)

            % TODO: verify these step sizes are appropriate for derivatives
            T_step = 0.01;
            P_step = 10;

            r.drho_dT_P = (obj.density(T + T_step, P) - obj.density(T - T_step, P)) / (2 * T_step);
            r.drho_dP_T = (obj.density(T, P + P_step) - obj.density(T, P - P_step)) / (2 * P_step);

            r.rho = obj.density(T, P);
            r.h = obj.enthalpy(T, P);
            r.u = obj.internalEnergy(T, P);

            r.du_dT_P = (obj.internalEnergy(T + T_step, P) - obj.internalEnergy(T - T_step, P)) / (2 * T_step);
            r.du_dP_T = (obj.internalEnergy(T, P + P_step) - obj.internalEnergy(T, P - P_step)) / (2 * P_step);

            r.CP = (obj.enthalpy(T + T_step, P) - obj.enthalpy(T - T_step, P)) / (2 * T_step);

            r.k = 0.0444697807 + T .* (0.000493824871 + T .* (-1.67948837E-07 + T .* 5.69883000E-11));
            r.mu = 0.00000242740665 + T .* (2.37814192E-08 + T .* (-7.11281496E-12 + T .* 1.62556323E-15));
        end

        function rho = density(obj, T, P)
            P_max = 50e6;
            T_ref = 200;
            DT_ref = T - T_ref;
            DP_log = log10(P) - log10(P_max);
            c1 = 0.434714996;
            c2 = 0.361637543;
            c3 = 279.646791;
            R = 4124.177;

            DZ_max = c1 - c2 * (1 - exp(-DT_ref / c3));
            DZ = 10.^DP_log .* DZ_max;
            Z = 1 + DZ;
            v = Z * R .* T ./ P;

            rho = 1 ./ v;
        end

        function h = enthalpy(obj, T, P)
            P_max = 50e6;  % [Pa]
            T_ref = 200;  % [K]
            a = 0.003950;  % [J/kg-K3]
            b = 0.001000957;  % [1/K]
            c = -0.4951407;  % [J/kg-K3]
            d = 0.0223508;  % [1/K]

            CPo_ref = 13480;  % [J/kg-K]
            d_CPo_ref_dT = 21.62242;  % [J/kg-K2]
            ho_ref = 2.557e6;  % [J/kg]

            DT_ref = T - T_ref;
            DP_log = log10(P) - log10(P_max);

            ho = ho_ref + CPo_ref .* DT_ref + (a / b + c / d + d_CPo_ref_dT) * 0.5 .* DT_ref.^2 - (a / b^2 + c / d^2) .* DT_ref + a / b^3 .* (1 - exp(-b .* DT_ref)) + c / d^3 .* (1 - exp(-d .* DT_ref));

            a_slope = 5.497 - (5.497 - 3.118) * (1 - exp(-(DT_ref.^0.7874) / 26.16));

            Dh_Pmax = 215003 + 224337.507 * (1-exp(-DT_ref/207.80827));
            Dh_P = 2 .* Dh_Pmax ./ (1 + exp(-a_slope .* DP_log));

            h = ho + Dh_P;
        end

        function u = internalEnergy(obj, T, P)
            u = obj.enthalpy(T, P) - P ./ obj.density(T, P);
        end
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            gridLayout.ColumnWidth = {"fit"};
            gridLayout.RowHeight = {"fit"};
            uilabel(                                                   ...
                gridLayout,                                            ...
                "Text", "This model does not require any parameters",  ...
                "FontAngle", "italic"                                  ...
            );

            getParams = @getParamsFunc;
            function r = getParamsFunc()
                r = false;  % indicates no params are required
            end
        end
    end
end
