% ED_modelos.m
% Proyecto integrador PAO 3 - Sistema de monitoreo de calidad del aire
% Ecuaciones Diferenciales: modelo de mezclas (CO2) y ley de enfriamiento de Newton
% Los parametros son SUPUESTOS para el avance de medio ciclo.
% Los modelos sirven para cualquier espacio cerrado: solo cambian V, Q y n.
% Al final guarda las figuras ED1, ED2 y ED3 en PNG en la carpeta actual.
clc; clear; close all;
rng(1);   % misma "medicion simulada" cada vez que se corre

%% ---------------- Modelo 1: mezclas (ejemplo: espacio de 144 m^3) ----------------
% dC/dt = G/V - (Q/V)(C - Cext)    ->    C(t) = Css + (C0 - Css) e^(-kt)
V    = 144;        % volumen del espacio (m^3): ejemplo 8 x 6 x 3 m
n    = 30;         % personas
g    = 5e-6;       % CO2 que exhala una persona (m^3/s)
Cext = 420;        % CO2 del aire exterior (ppm)
C0   = 420;        % CO2 al empezar (ppm)
G    = 1e6*g*n;    % generacion (ppm*m^3/s) = 150

Q = [0.02 0.21 0.2586];        % ventilacion (m^3/s)
t = linspace(0, 120, 600);     % tiempo (min)

figure(1); hold on; grid on;
for i = 1:length(Q)
    k   = Q(i)/V*60;           % constante (1/min)
    Css = Cext + G/Q(i);       % valor de equilibrio (ppm)
    C   = Css + (C0 - Css)*exp(-k*t);
    plot(t, C, 'LineWidth', 2);
    C60 = Css + (C0 - Css)*exp(-k*60);
    fprintf('Q = %.4f m3/s | k = %.5f 1/min | tau = %.1f min | Css = %.0f ppm | C(60) = %.0f ppm\n', ...
            Q(i), k, 1/k, Css, C60);
    if Css > 1000
        t1000 = -log((Css - 1000)/(Css - C0))/k;
        fprintf('   llega a 1000 ppm a los %.1f min\n', t1000);
    end
end
plot([0 120], [1000 1000], 'k--');
xlabel('Tiempo t (min)'); ylabel('CO_2 C(t) (ppm)');
title('Mezclas: espacio de 144 m^3 con 30 personas');
legend('Q = 0,02 m^3/s', 'Q = 0,21 m^3/s', 'Q = 0,26 m^3/s', '1000 ppm', 'Location', 'northwest');
ylim([300 4000]);
print(gcf, '-dpng', '-r200', 'ED1_co2_aula.png');

% Ventilacion minima para no pasar de 1000 ppm
Qmin = G/(1000 - Cext);
fprintf('Ventilacion minima: %.3f m3/s (%.1f L/s por persona)\n\n', Qmin, Qmin/n*1000);

% Comprobacion: solucion numerica con ode45 (caso Q = 0,21)
k   = 0.21/V*60;
dC  = @(tt, C) 60*G/V - k*(C - Cext);         % ppm/min
[tn, Cn] = ode45(dC, [0 120], C0);
Css = Cext + G/0.21;
Can = Css + (C0 - Css)*exp(-k*tn);
fprintf('Diferencia maxima ode45 vs analitica: %.4f ppm\n\n', max(abs(Cn - Can)));

%% ---------------- Maqueta: decaimiento del humo (G = 0) ----------------
Vm   = 0.03;                 % volumen de la maqueta (m^3)
Qm   = [0.001 0.0001];       % extractor encendido y apagado (m^3/s)
Cm0  = 2000;                 % concentracion inicial (ppm)
tm   = linspace(0, 10, 500); % tiempo (min)
figure(2); hold on; grid on;
for i = 1:length(Qm)
    km = Qm(i)/Vm*60;        % 1/min
    plot(tm, Cext + (Cm0 - Cext)*exp(-km*tm), 'LineWidth', 2);
    fprintf('Maqueta Q = %.4f m3/s | tau = %.1f s | 95%% limpio en %.1f min\n', Qm(i), 60/km, 3/km);
end
plot([0 10], [Cext Cext], 'k--');
xlabel('Tiempo t (min)'); ylabel('Concentracion C(t) (ppm)');
title('Maqueta: decaimiento despues de llenarla de humo');
legend('Extractor encendido', 'Extractor apagado', 'Aire exterior');
print(gcf, '-dpng', '-r200', 'ED2_maqueta.png');

%% ---------------- Modelo 2: ley de enfriamiento de Newton ----------------
% dT/dt = -k (T - Ta)    ->    T(t) = Ta + (T0 - Ta) e^(-kt)
Ta = 22; T0 = 30; kT = 0.05;     % supuestos: equilibrio 22 C, inicio 30 C, k en 1/min
tt = linspace(0, 90, 500);
T  = Ta + (T0 - Ta)*exp(-kT*tt);
figure(3); plot(tt, T, 'LineWidth', 2); hold on; grid on;
plot([0 90], [Ta Ta], 'k--'); plot([0 90], [25 25], 'k:');
xlabel('Tiempo t (min)'); ylabel('Temperatura T(t) (^{\circ}C)');
title('Newton: local con aire acondicionado');
ylim([21 31]); xlim([0 90]);
legend('T(t)', 'T_a = 22 ^{\circ}C', '25 ^{\circ}C', 'Location', 'northeast');
print(gcf, '-dpng', '-r200', 'ED3_newton.png');
fprintf('\nT(30) = %.2f C | llega a 25 C a los %.1f min\n', Ta + (T0 - Ta)*exp(-kT*30), log((T0 - Ta)/(25 - Ta))/kT);

%% ---------------- Para el segundo ciclo: sacar k de los datos ----------------
% ln((C - Cext)/(C0 - Cext)) = -k t  ->  recta; la pendiente es -k
% Aqui se prueba el metodo con datos simulados (curva del extractor encendido + ruido)
km_real = 0.001/Vm*60;
td = (0:4:240)'/60;                                     % una lectura cada 4 s (min)
Cd = Cext + (Cm0 - Cext)*exp(-km_real*td) + 5*randn(size(td));
usar = Cd - Cext > 20;                                   % evita el log de valores muy chicos
coef = polyfit(td(usar), log((Cd(usar) - Cext)/(Cm0 - Cext)), 1);
k_estimado = -coef(1);
fprintf('\nk real = %.3f 1/min | k estimado con los datos = %.3f 1/min | Q estimado = %.2f L/s\n', ...
        km_real, k_estimado, k_estimado*Vm/60*1000);
