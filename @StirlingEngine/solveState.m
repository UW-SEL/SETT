function x = solveState(obj, T_c, T_e, P, t)
    % SOLVESTATE Solve the instantaneous state equations
    %
    % Inputs:
    %   T_c -- compression space temperature (K)
    %   T_e -- expansion space temperature (K)
    %   P   -- engine pressure (Pa)
    %   t   -- time (s)
    %
    % Output:
    %   x(1)  -- m_dot_ck (kg/s)
    %   x(2)  -- m_dot_kr (kg/s)
    %   x(3)  -- m_dot_rl (kg/s)
    %   x(4)  -- m_dot_le (kg/s)
    %   x(5)  -- Q_dot_k (W)
    %   x(6)  -- Q_dot_r (W)
    %   x(7)  -- Q_dot_l (W)
    %   x(8)  -- dTc_dt (K/s)
    %   x(9)  -- dTe_dt (K/s)
    %   x(10) -- dP_dt (P/s)
    % if obj.isInnerLoop
        % obj.counter = obj.counter + 1;
        % fprintf("%.12e %.12e %.12e %.12e",t, T_c, T_e, P)
        % disp(obj.counter)
    % end
    % Get working spaces values at this time
    [V_c, dVc_dt, V_e, dVe_dt] = obj.ws.values(t);
    Q_dot_c = (T_c - obj.T_k) / obj.ws.R_c;
    Q_dot_e = (T_e - obj.T_l) / obj.ws.R_e;

    % Calculate thermodynamic properties for each volume
    props_c = obj.fluid.allProps(T_c, P);
    props_k = obj.fluid.allProps(obj.T_k, P);
    props_r = obj.fluid.allProps(obj.T_r, P);
    props_r_hot = obj.fluid.allProps(obj.T_r_hot, P);
    props_r_cold = obj.fluid.allProps(obj.T_r_cold, P);
    props_l = obj.fluid.allProps(obj.T_l, P);
    props_e = obj.fluid.allProps(T_e, P);

    % Get normalizing enthalpy
    T_ave = (obj.T_cold + obj.T_hot) / 2;
    % h_norm = obj.fluid.enthalpy(T_ave, obj.P_0);  % TODO: use this when enthalpy() available on all fluids
    h_norm = obj.fluid.allProps(T_ave, obj.P_0).h;

    % The state is first solved using averaged enthalpies to determine flow directions
    h_ck = 0.5 * (props_c.h + props_k.h);
    h_kr = 0.5 * (props_k.h + props_r_cold.h);
    h_rl = 0.5 * (props_r_hot.h + props_l.h);
    h_le = 0.5 * (props_l.h + props_e.h);

    A = zeros(10, 10);
    b = zeros(10, 1);

    % Mass balance on compression space
    A(1,1) = 1;  % m_dot_ck
    A(1,8) = V_c * props_c.drho_dT_P;   % dTc_dt
    A(1,10) = V_c * props_c.drho_dP_T;  % dP_dt
    b(1) = -props_c.rho * dVc_dt;

    % Energy balance on compression space
    A(2,1) = h_ck / h_norm;  % m_dot_ck
    A(2,8) = V_c * (props_c.rho * props_c.du_dT_P + props_c.u * props_c.drho_dT_P) / h_norm;   % dTc_dt
    A(2,10) = V_c * (props_c.rho * props_c.du_dP_T + props_c.u * props_c.drho_dP_T) / h_norm;  % dP_dt
    b(2) = (-(P + props_c.rho * props_c.u) * dVc_dt - Q_dot_c) / h_norm;

    % Mass balance on cold heat exchanger
    A(3,1) = -1;  % m_dot_ck
    A(3,2) = 1;   % m_dot_kr
    A(3,10) = obj.V_k * props_k.drho_dP_T;  % dP_dt

    % Energy balance on cold heat exchanger
    A(4,1) = -h_ck / h_norm;  % m_dot_ck
    A(4,2) = h_kr / h_norm;   % m_dot_kr
    A(4,5) = 1 / h_norm;      % Q_dot_k
    A(4,10) = obj.V_k * (props_k.rho * props_k.du_dP_T + props_k.u * props_k.drho_dP_T) / h_norm;  % dP_dt

    % Mass balance on regenerator
    A(5,2) = -1;  % m_dot_kr
    A(5,3) = 1;   % m_dot_rl
    A(5,10) = obj.V_r * props_r.drho_dP_T;  % dP_dt

    % Energy balance on regenerator
    A(6,2) = -h_kr / h_norm;  % m_dot_kr
    A(6,3) = h_rl / h_norm;   % m_dot_rl
    A(6,6) = 1 / h_norm;      % Q_dot_r
    A(6,10) = obj.V_r * (props_r.rho * props_r.du_dP_T + props_r.u * props_r.drho_dP_T) / h_norm;  % dP_dt

    % Mass balance on hot heat exchanger
    A(7,3) = -1;  % m_dot_rl
    A(7,4) = 1;   % m_dot_le
    A(7,10) = obj.V_l * props_l.drho_dP_T;  % dP_dt

    % Energy balance on hot heat exchanger
    A(8,3) = -h_rl / h_norm;  % m_dot_rl
    A(8,4) = h_le / h_norm;   % m_dot_le
    A(8,7) = -1 / h_norm;     % Q_dot_l
    A(8,10) = obj.V_l * (props_l.rho * props_l.du_dP_T + props_l.u * props_l.drho_dP_T) / h_norm;  % dP_dt

    % Mass balance on expansion space
    A(9,4) = -1;  % m_dot_le
    A(9,9) = V_e * props_e.drho_dT_P;   % dTe_dt
    A(9,10) = V_e * props_e.drho_dP_T;  % dP_dt
    b(9) = -props_e.rho * dVe_dt;

    % Energy balance on expansion space
    A(10,4) = -h_le / h_norm;  % m_dot_le
    A(10,9) = V_e * (props_e.rho * props_e.du_dT_P + props_e.u * props_e.drho_dT_P) / h_norm;   % dTe_dt
    A(10,10) = V_e * (props_e.rho * props_e.du_dP_T + props_e.u * props_e.drho_dP_T) / h_norm;  % dP_dt
    b(10) = (-(P + props_e.rho * props_e.u) * dVe_dt - Q_dot_e) / h_norm;

    % Condition matrix and solve equations
    [P,R,C] = equilibrate(A);
    A_improved = R * P * A * C;
    b_improved = R * P * b;
    y = A_improved \ b_improved;
    x = C * y;

    % Ensure the correct enthalpies are used based on mass flow directions
    counter = 0;
    while true
        counter = counter + 1;
        if counter > 5
            warning("Unable to determine consistent mass flow directions")
            break
        end

        % Set enthalpies based on last calculated mass flow directions
        if x(1) > 0; h_ck = props_c.h; else; h_ck = props_k.h; end       % checking m_dot_ck
        if x(2) > 0; h_kr = props_k.h; else; h_kr = props_r_cold.h; end  % checking m_dot_kr
        if x(3) > 0; h_rl = props_r_hot.h; else; h_rl = props_l.h; end   % checking m_dot_rl
        if x(4) > 0; h_le = props_l.h; else; h_le = props_e.h; end       % checking m_dot_le
        isPositiveDirection = x(1:4) > 0;

        % Adjust the enthalpy entries in the A matrix
        A(2,1) = h_ck / h_norm;
        A(4,1) = -h_ck / h_norm;
        A(4,2) = h_kr / h_norm;
        A(6,2) = -h_kr / h_norm;
        A(6,3) = h_rl / h_norm;
        A(8,3) = -h_rl / h_norm;
        A(8,4) = h_le / h_norm;
        A(10,4) = -h_le / h_norm;

        % Condition updated matrix and solve equations
        [P,R,C] = equilibrate(A);
        A_improved = R * P * A * C;
        b_improved = R * P * b;
        y = A_improved \ b_improved;
        x = C * y;
        % TODO: investigate using linsolve(A,b) and its options instead of A \ b

        if all(isPositiveDirection == (x(1:4) > 0))
            break
        end
    end
end
