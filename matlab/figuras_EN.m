% figuras_EN.m
% Integrator project PAO 3 - Air quality monitoring system
% English figures for the slides (same models as ED_modelos.m and VV_funciones.m).
% Values are ASSUMED for the mid-term progress. Saves landscape PNG files.
clc; clear; close all;

%% Mixing model (CO2): example of a closed space of 144 m^3 with 30 people
V = 144; n = 30; G = 1e6*5e-6*n; Cext = 420; C0 = 420;
Q = [0.02 0.21 0.2586];
t = linspace(0, 120, 600);
figure; hold on; grid on;
for i = 1:length(Q)
    k = Q(i)/V*60; Css = Cext + G/Q(i);
    plot(t, Css + (C0 - Css)*exp(-k*t), 'LineWidth', 2);
end
plot([0 120], [1000 1000], 'k--');
xlabel('Time t (min)'); ylabel('CO_2 C(t) (ppm)'); ylim([300 4000]);
title('Mixing model: 144 m^3 closed space, 30 people (example)');
legend('Q = 0.02 m^3/s', 'Q = 0.21 m^3/s (7 L/s per person)', 'Q = 0.26 m^3/s (8.6 L/s per person)', '1000 ppm', 'Location', 'northwest');
guardar('ED1_co2_EN.png', 7.2, 4.2);

%% Model classroom: smoke decay (G = 0)
Vm = 0.03; Qm = [0.001 0.0001]; Cm0 = 2000; tm = linspace(0, 10, 500);
figure; hold on; grid on;
for i = 1:length(Qm)
    km = Qm(i)/Vm*60;
    plot(tm, Cext + (Cm0 - Cext)*exp(-km*tm), 'LineWidth', 2);
end
plot([0 10], [Cext Cext], 'k--');
xlabel('Time t (min)'); ylabel('Concentration C(t) (ppm)');
title('Model classroom (V = 0.03 m^3): decay after filling it with smoke');
legend('Fan ON', 'Fan OFF', 'Outdoor air');
guardar('ED2_model_classroom_EN.png', 7.2, 4.0);

%% Newton's law of cooling
Ta = 22; T0 = 30; kT = 0.05; tt = linspace(0, 90, 500);
figure; plot(tt, Ta + (T0 - Ta)*exp(-kT*tt), 'LineWidth', 2); hold on; grid on;
plot([0 90], [Ta Ta], 'k--'); plot([0 90], [25 25], 'k:');
ylim([21 31]); xlim([0 90]);
xlabel('Time t (min)'); ylabel('Temperature T(t) (^{\circ}C)');
title('Newton''s law of cooling: shop with air conditioning');
legend('T(t)', 'T_a = 22 ^{\circ}C', '25 ^{\circ}C');
guardar('ED3_newton_EN.png', 7.2, 4.0);

%% Discomfort index DI(T,H)
DI = @(T, H) T - 0.55*(1 - 0.01*H).*(T - 14.5);
[T, H] = meshgrid(20:0.25:40, 30:1:100);
Z = DI(T, H);
figure;
surf(T, H, Z, 'EdgeAlpha', 0.15); colormap(bone); shading interp; hold on;
plot3(30, 80, DI(30, 80), 'o', 'MarkerSize', 7, 'MarkerFaceColor', [0.7 0.4 0.3], 'MarkerEdgeColor', 'k');
xlabel('T (^{\circ}C)'); ylabel('H (%)'); zlabel('DI (^{\circ}C)');
title('Discomfort index DI(T, H), point (30, 80) = 28.3'); view(-130, 24);
guardar('VV1_DI_surface_EN.png', 7.2, 5.0);

figure;
[cs, hc] = contour(T, H, Z, [21 24 27 29 32], 'LineWidth', 1.5);
clabel(cs, hc); grid on; hold on;
plot(30, 80, 'o', 'MarkerFaceColor', [0.7 0.4 0.3]);
xlabel('Temperature T (^{\circ}C)'); ylabel('Relative humidity H (%)');
title('Level curves of DI(T, H): limits of the discomfort categories');
guardar('VV2_DI_level_curves_EN.png', 7.2, 4.6);

%% Equilibrium CO2 Css(n,Q)
Css = @(n, Q) 420 + 5*n./Q;
[N, Qg] = meshgrid(1:0.2:40, 0.03:0.005:0.5);
figure;
[cs2, hc2] = contour(N, Qg, Css(N, Qg), [600 800 1000 1500 2500], 'LineWidth', 1.5);
clabel(cs2, hc2); grid on; hold on;
plot(30, 0.21, 'o', 'MarkerFaceColor', [0.7 0.4 0.3]);
xlabel('Number of people n'); ylabel('Ventilation Q (m^3/s)');
title('Level curves of Css(n, Q) = 420 + 5n/Q');
guardar('VV3_Css_level_curves_EN.png', 7.2, 4.6);

disp('English figures saved');

function guardar(nombre, ancho, alto)
    % landscape axes inside the docked figure; exportgraphics crops the white margins
    h = 0.8*alto/ancho; set(gca,'Position',[0.12 0.5-h/2 0.83 h]);
    exportgraphics(gcf, nombre, 'Resolution', 200);
end
