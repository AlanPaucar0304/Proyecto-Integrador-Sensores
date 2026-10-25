% VV_funciones.m
% Proyecto integrador PAO 3 - Sistema de monitoreo de calidad del aire
% Calculo de Varias Variables: DI(T,H) y Css(n,Q)
% Notacion de clase (Ing. Hugo): DI'(T) = derivada respecto a T con H constante, etc.
% Al final guarda las figuras VV1, VV2 y VV3 en PNG en la carpeta actual.
clc; clear; close all;

%% ---------------- Funcion 1: indice de incomodidad DI(T,H) ----------------
DI = @(T, H) T - 0.55*(1 - 0.01*H).*(T - 14.5);

[T, H] = meshgrid(20:0.25:40, 30:1:100);
Z = DI(T, H);

figure(1);
surf(T, H, Z, 'EdgeAlpha', 0.15); colormap(bone); shading interp;
xlabel('T (^{\circ}C)'); ylabel('H (%)'); zlabel('DI (^{\circ}C)');
title('Indice de incomodidad DI(T,H)'); view(-130, 24);
print(gcf, '-dpng', '-r200', 'VV1_superficie_DI.png');

figure(2);
[cs, hc] = contour(T, H, Z, [21 24 27 29 32], 'LineWidth', 1.5);
clabel(cs, hc); grid on; hold on;
plot(30, 80, 'o', 'MarkerFaceColor', [0.7 0.4 0.3]);
xlabel('Temperatura T (^{\circ}C)'); ylabel('Humedad H (%)');
title('Curvas de nivel de DI: limites de las categorias');
print(gcf, '-dpng', '-r200', 'VV2_curvas_DI.png');

% Punto de analisis
T0 = 30; H0 = 80;
fprintf('DI(30,80) = %.2f C\n', DI(T0, H0));

% Derivadas parciales a mano y comprobacion numerica
DIT_mano = 0.45 + 0.0055*H0;          % DI'(T)  (H constante)
DIH_mano = 0.0055*(T0 - 14.5);        % DI'(H)  (T constante)
h = 1e-4;
DIT_num = (DI(T0 + h, H0) - DI(T0 - h, H0))/(2*h);
DIH_num = (DI(T0, H0 + h) - DI(T0, H0 - h))/(2*h);
fprintf('DI''(T): a mano = %.4f | numerica = %.4f\n', DIT_mano, DIT_num);
fprintf('DI''(H): a mano = %.4f | numerica = %.4f\n', DIH_mano, DIH_num);
% Segundo orden y mixta
DITT = (DI(T0 + h, H0) - 2*DI(T0, H0) + DI(T0 - h, H0))/h^2;
DIHH = (DI(T0, H0 + h) - 2*DI(T0, H0) + DI(T0, H0 - h))/h^2;
DITH = (DI(T0 + h, H0 + h) - DI(T0 + h, H0 - h) - DI(T0 - h, H0 + h) + DI(T0 - h, H0 - h))/(4*h^2);
fprintf('DI''''(T) = %.4f | DI''''(H) = %.4f | DI''TH = %.4f (a mano: 0, 0 y 0,0055)\n', DITT, DIHH, DITH);
fprintf('Gradiente en (30, 80): (%.3f ; %.3f)\n', DIT_mano, DIH_mano);

% Diferencial total con el error del DHT22
dT = 0.5; dH = 2;
errorDI = abs(DIT_mano)*dT + abs(DIH_mano)*dH;
fprintf('Error del indice por el sensor: +/- %.2f C\n', errorDI);

% Regla de la cadena con Newton (dT/dt = -0,05(30 - 22), H constante)
dTdt = -0.05*(30 - 22);
fprintf('DI''(t) = DI''(T) * T''(t) = %.3f C/min\n\n', DIT_mano*dTdt);

%% ---------------- Funcion 2: CO2 de equilibrio Css(n,Q) ----------------
Css = @(n, Q) 420 + 5*n./Q;
[N, Q] = meshgrid(1:0.2:40, 0.03:0.005:0.5);
figure(3);
[cs2, hc2] = contour(N, Q, Css(N, Q), [600 800 1000 1500 2500], 'LineWidth', 1.5);
clabel(cs2, hc2); grid on; hold on;
plot(30, 0.21, 'o', 'MarkerFaceColor', [0.7 0.4 0.3]);
xlabel('Numero de personas n'); ylabel('Ventilacion Q (m^3/s)');
title('Curvas de nivel de Css(n,Q) = 420 + 5n/Q');
print(gcf, '-dpng', '-r200', 'VV3_curvas_Css.png');

n0 = 30; Q0 = 0.21;
fprintf('Css(30, 0.21) = %.0f ppm\n', Css(n0, Q0));
fprintf('Css''(n) = %.2f ppm por persona\n', 5/Q0);
fprintf('Css''(Q) = %.0f ppm por m3/s\n', -5*n0/Q0^2);
fprintf('Css''''(Q) = %.0f | Css''nQ = %.1f\n', 10*n0/Q0^3, -5/Q0^2);
fprintf('Curva de 1000 ppm: Q = %.5f n  ->  para 30 personas Q = %.3f m3/s\n', 5/580, 5*30/580);
