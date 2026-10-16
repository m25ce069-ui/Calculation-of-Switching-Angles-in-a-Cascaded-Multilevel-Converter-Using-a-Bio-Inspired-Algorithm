function salida = CHB_UNIFICADO(modo, archivoMAT)
% CHB_UNIFICADO: comparativa, espectros y analisis en un unico archivo.
%   CHB_UNIFICADO                  : estudio principal, 30 corridas/metodo.
%   CHB_UNIFICADO('prueba')        : prueba corta de integracion (NO publicar).
%   CHB_UNIFICADO('completo')      : principal + sensibilidad + otros voltajes.
%   CHB_UNIFICADO('autoprueba')    : comprueba nucleo numerico y presupuesto.
%   CHB_UNIFICADO('graficas',ruta) : regenera figuras desde estudio.mat.
% Recomendado: MATLAB R2020a o posterior. No requiere Statistics Toolbox.
% Algoritmos originales del ZIP del autor; operadores conservados por defecto.
% Simulacion ANALITICA ideal CHB; no incluye Simulink ni hardware.
if nargin<1, modo='principal'; end
if nargin<2, archivoMAT=''; end
modo=lower(char(modo));
cfg=configuracion_chb();
if strcmp(modo,'autoprueba')
    autoprueba_chb(cfg); salida='Autopruebas completadas'; return;
end
if strcmp(modo,'graficas')
    assert(exist(archivoMAT,'file')==2,'Indique la ruta a estudio.mat.');
    S=load(archivoMAT,'estudio'); estudio=S.estudio;
    % Se pueden modificar fuentes/resolucion en configuracion_chb y regenerar.
    estudio.cfg.grafica=cfg.grafica;
    destino=fullfile(fileparts(archivoMAT),['figuras_' datestr(now,'yyyymmdd_HHMMSS')]);
    mkdir(destino); graficas_chb(estudio,destino); salida=destino; return;
end
assert(any(strcmp(modo,{'principal','prueba','completo'})),'Modo desconocido.');
if strcmp(modo,'prueba')
    cfg.Np=20; cfg.MaxEval=420; cfg.Semillas=(1:3)'; cfg.EsPrueba=true;
end
validar_cfg(cfg);
raiz=fileparts(mfilename('fullpath'));
stamp=datestr(now,'yyyymmdd_HHMMSS');
salida=fullfile(raiz,['resultados_CHB_' modo '_' stamp]);
if exist(salida,'dir'), salida=[salida '_' sprintf('%06d',round(rem(now,1)*1e6))]; end
mkdir(salida);
copyfile([mfilename('fullpath') '.m'],fullfile(salida,'CHB_UNIFICADO_usado.m'));
entorno=entorno_chb();
fid=fopen(fullfile(salida,'entorno_y_protocolo.txt'),'w');
assert(fid>=0,'No se puede escribir en la carpeta de resultados.');
fprintf(fid,'%s\n',evalc('disp(entorno)'));
fprintf(fid,['Modelo analitico ideal; sin circuito conmutado ni hardware.\n' ...
    'Tiempo_s: ejecucion sin registro detallado (si MedirSinRegistro=true).\n' ...
    'TiempoInstrumentado_s: ejecucion con registro de mejoras.\n' ...
    'TiempoHastaObjetivo_s pertenece a la ejecucion instrumentada.\n' ...
    'Incluye inicializacion, objetivo, reparacion y operadores; excluye graficas y archivos.\n' ...
    'Las semillas emparejan poblaciones iniciales dentro de cada caso.\n' ...
    'Objetivo empirico por caso: menor J final observado + tolerancia. No es optimo probado.\n' ...
    'Las corridas sin objetivo alcanzado conservan NaN; no se sustituyen por el presupuesto.\n' ...
    'Sensibilidad: un factor a la vez, no ajuste automatico ni parametros optimos.\n' ...
    'Las diferencias numericas/estadisticas no demuestran relevancia fisica.\n']);
fclose(fid);
casos=crear_casos(cfg,modo);
resumenGeneral=table();
fprintf('\nModo %s: %d casos. Salida: %s\n',modo,numel(casos),salida);
if strcmp(modo,'completo')
    fprintf('El modo completo realiza muchos mas ensayos que las 120 corridas principales.\n');
end
for c=1:numel(casos)
    caso=casos(c); sub=fullfile(salida,caso.nombre); mkdir(sub);
    fprintf('\n=== %s (%d metodos, Np=%d, V1*=%.2f V) ===\n', ...
        caso.nombre,numel(caso.metodos),caso.cfg.Np,caso.cfg.Vref);
    estudio=ejecutar_caso(caso,sub,entorno);
    save(fullfile(sub,'estudio.mat'),'estudio','-v7');
    exportar_caso(estudio,sub);
    graficas_chb(estudio,sub);
    T=estudio.resumen;
    T.Caso=repmat({caso.nombre},height(T),1);
    T.Np=repmat(caso.cfg.Np,height(T),1);
    T.Vref_V=repmat(caso.cfg.Vref,height(T),1);
    T.F_DE=repmat(caso.cfg.F,height(T),1);
    T.Cr_DE=repmat(caso.cfg.Cr,height(T),1);
    T.a0_GWO=repmat(caso.cfg.a0,height(T),1);
    T.Td0_AFTA=repmat(caso.cfg.Td0,height(T),1);
    T.PpFactor_AFTA=repmat(caso.cfg.PpFactor,height(T),1);
    T.TF_TLBO=repmat(caso.cfg.TF,height(T),1);
    if isempty(resumenGeneral), resumenGeneral=T; else, resumenGeneral=[resumenGeneral;T]; end %#ok<AGROW>
    writetable(resumenGeneral,fullfile(salida,'resumen_todos_los_casos.csv'));
end
save(fullfile(salida,'configuracion_y_entorno.mat'),'cfg','casos','entorno');
fprintf('\nTERMINADO. Archivos en:\n%s\n',salida);
end

function cfg=configuracion_chb()
% EDITAR AQUI. Las configuraciones se guardan con cada estudio.
cfg.Vdc=[83.33 83.33 83.33]; cfg.Vref=250; cfg.Hmax=49; cfg.lambdaV=10;
cfg.Np=1000; cfg.MaxEval=201000; cfg.Semillas=(1:30)';
cfg.F=0.3; cfg.Cr=0.9;
cfg.a0=2; cfg.Td0=2; cfg.PpFactor=0.1;
cfg.TF=0; % 0: randi([1 2]) original; 1/2: TF fijo para sensibilidad.
cfg.TolV=0.1; cfg.TolJ=1e-3;
cfg.MedirSinRegistro=true; % repite semilla; separa costo del registro.
cfg.Calentar=true;         % calentamiento corto, fuera de tiempos reportados.
cfg.EsPrueba=false;
cfg.grafica.Fuente=13; cfg.grafica.Etiquetas=15;
cfg.grafica.Titulo=15; cfg.grafica.Leyenda=12;
cfg.grafica.Ancho_cm=19; cfg.grafica.Alto_cm=13;
cfg.grafica.DPI=600; cfg.grafica.Visible='off';
cfg.grafica.Cerrar=true;
cfg.grafica.Colores=[0 .447 .741;.85 .325 .098;.25 .60 .30;.494 .184 .556];
cfg.grafica.Exportar=true;
% Redondeo SOLO para rangos estadisticos; CSV y calculos conservan precision.
cfg.Quantum=[1e-9 1e-9 1e-9 1e-6]; % J, THD(%), error(V), tiempo(s).
end

function validar_cfg(cfg)
assert(numel(cfg.Vdc)==3 && all(isfinite(cfg.Vdc)) && all(cfg.Vdc>0));
assert(cfg.Vref>0 && cfg.Vref<4*sum(cfg.Vdc)/pi,'Vref fuera del rango analitico.');
assert(cfg.Hmax>=3 && mod(cfg.Hmax,2)==1 && cfg.Hmax==fix(cfg.Hmax));
assert(cfg.Np>=4 && cfg.Np==fix(cfg.Np));
assert(cfg.MaxEval>=2*cfg.Np && mod(cfg.MaxEval,cfg.Np)==0, ...
    'MaxEval debe ser multiplo de Np y permitir al menos un lote adicional.');
assert(numel(unique(cfg.Semillas))==numel(cfg.Semillas),'Semillas repetidas.');
assert(cfg.F>0 && cfg.Cr>=0 && cfg.Cr<=1 && cfg.a0>=0);
assert(cfg.Td0>0 && cfg.PpFactor>=0 && any(cfg.TF==[0 1 2]));
assert(cfg.TolV>=0 && cfg.TolJ>=0 && cfg.lambdaV>0);
end

function casos=crear_casos(cfg,modo)
casos=struct('nombre',sprintf('principal_%gV',cfg.Vref),'cfg',cfg,'metodos',{{'DE','TLBO','GWO','AFTA'}});
if ~strcmp(modo,'completo'), return; end
for n=[50 100 250 500]
    q=cfg; q.Np=n; casos(end+1)=nuevo_caso(sprintf('poblacion_%d',n),q,casos(1).metodos); %#ok<AGROW>
end
for v=[200 225 275]
    q=cfg; q.Vref=v; casos(end+1)=nuevo_caso(sprintf('referencia_%dV',v),q,casos(1).metodos); %#ok<AGROW>
end
q=cfg; q.Vdc=cfg.Vdc.*[.9 1 1.1];
casos(end+1)=nuevo_caso('fuentes_desiguales',q,casos(1).metodos);
parametros={'F','Cr','a0','Td0','PpFactor','TF'};
valores={[.2 .5],[.7 .95],[1 3],[1 3],[.05 .2],[1 2]};
metodos={'DE','DE','GWO','AFTA','AFTA','TLBO'};
for p=1:numel(parametros)
    for v=valores{p}
        q=cfg; q.(parametros{p})=v;
        nombre=strrep(sprintf('sens_%s_%s_%g',metodos{p},parametros{p},v),'.','p');
        casos(end+1)=nuevo_caso(nombre,q,metodos(p)); %#ok<AGROW>
    end
end
end
function c=nuevo_caso(nombre,cfg,metodos)
validar_cfg(cfg); c=struct('nombre',nombre,'cfg',cfg,'metodos',{metodos});
end

function estudio=ejecutar_caso(caso,sub,entorno)
cfg=caso.cfg; M=numel(caso.metodos); R=numel(cfg.Semillas);
runs=cell(R,M); E=(cfg.Np:cfg.Np:cfg.MaxEval)';
conv=nan(numel(E),R,M);
if cfg.Calentar
    q=cfg; q.Np=10; q.MaxEval=30;
    for m=1:M
        rng(9000+m,'twister');
        llamar_algoritmo(caso.metodos{m},@(x)objetivo_chb(x,q),q);
    end
end
for r=1:R
    % Rotacion determinista del orden: reduce sesgo termico/de orden.
    orden=mod((0:M-1)+(r-1),M)+1;
    for m=orden
        s=cfg.Semillas(r);
        if cfg.MedirSinRegistro && mod(r,2)==0
            [plain,tp]=corrida_sin_registro(caso.metodos{m},cfg,s);
        end
        run=corrida_instrumentada(caso.metodos{m},cfg,s);
        if cfg.MedirSinRegistro
            if mod(r,2)==1, [plain,tp]=corrida_sin_registro(caso.metodos{m},cfg,s); end
            assert(abs(plain.J-run.J)<=1e-10*max(1,abs(run.J)) && ...
                max(abs(plain.x-run.x))<=1e-9, ...
                'El registro altero el resultado o la secuencia aleatoria.');
            run.Tiempo_s=tp;
        else
            run.Tiempo_s=run.TiempoInstrumentado_s;
        end
        runs{r,m}=run;
        assert(isequal(run.evalHist(:),E),'Presupuesto/historial incorrecto.');
        conv(:,r,m)=run.hist(:);
        fprintf('%s semilla %d: J=%.9f, THD=%.9f%%, error=%.3g V, t=%.4f s\n', ...
            caso.metodos{m},s,run.J,run.THD,run.ErrorV,run.Tiempo_s);
        save(fullfile(sub,'avance.mat'),'runs','caso','conv','E','-v7');
    end
end
valJ=cellfun(@(r)r.J,runs); Jref=min(valJ(:)); limite=Jref+cfg.TolJ;
filas=cell(R*M,20); fila=0;
for m=1:M
    for r=1:R
        u=runs{r,m}; ev=u.eventos;
        k=find(ev(:,2)<=limite & ev(:,5)<=cfg.TolV,1,'first');
        hit=~isempty(k); eh=NaN; th=NaN;
        if hit, eh=ev(k,1); th=ev(k,6); end
        u.ExitoFinal=u.J<=limite && u.ErrorV<=cfg.TolV;
        u.AlcanzoObjetivo=hit; u.EvalHastaObjetivo=eh; u.TiempoHastaObjetivo=th;
        runs{r,m}=u;
        fila=fila+1;
        filas(fila,:)={caso.metodos{m},r,cfg.Semillas(r),u.x(1),u.x(2),u.x(3), ...
            u.J,u.THD,u.V1,u.ErrorV,u.Tiempo_s,u.TiempoInstrumentado_s, ...
            cfg.MaxEval,u.ExitoFinal,hit,eh,th,Jref,limite,1e6*u.Tiempo_s/cfg.MaxEval};
    end
end
nombres={'Metodo','Corrida','Semilla','Alpha1_deg','Alpha2_deg','Alpha3_deg', ...
    'FuncionObjetivo_J','THD_pct','V1_V','ErrorV_V','Tiempo_s','TiempoInstrumentado_s', ...
    'EvaluacionesTotales','ExitoFinal','AlcanzoObjetivo','EvaluacionesHastaObjetivo', ...
    'TiempoHastaObjetivo_s','JReferenciaEmpirica','LimiteJ','TiempoAmortizado_us_eval'};
T=cell2table(filas,'VariableNames',nombres);
estudio=struct('cfg',cfg,'caso',caso.nombre,'metodos',{caso.metodos}, ...
    'runs',{runs},'E',E,'conv',conv,'resultados',T,'Jref',Jref,'entorno',entorno);
estudio.resumen=resumir_chb(estudio);
estudio.estadistica=estadistica_chb(estudio);
end

function [p,t]=corrida_sin_registro(metodo,cfg,semilla)
rng(semilla,'twister');
[x,f,~,~,t]=llamar_algoritmo(metodo,@(x)objetivo_chb(x,cfg),cfg);
p=struct('x',x,'J',f);
end

function run=corrida_instrumentada(metodo,cfg,semilla)
% Solo registra nuevas mejores soluciones factibles; no consume aleatoriedad.
% Columnas: evaluacion,J,THD,V1,error,tiempo,alpha1,alpha2,alpha3.
ne=0; nb=0; best=Inf; eventos=nan(cfg.MaxEval,9);
rng(semilla,'twister'); reloj=tic;
[x,f,h,eh,~]=llamar_algoritmo(metodo,@medir,cfg);
t=toc(reloj);
assert(ne==cfg.MaxEval,'Numero real de evaluaciones incorrecto.');
[j,hc,thd,v,er]=objetivo_chb(x,cfg);
assert(hc==0 && abs(j-f)<1e-8,'Solucion final inconsistente.');
assert(all(diff(h)<=1e-10),'El mejor J debe ser no creciente.');
run=struct('x',x,'J',j,'THD',thd,'V1',v,'ErrorV',er, ...
    'hist',h,'evalHist',eh,'TiempoInstrumentado_s',t,'eventos',eventos(1:nb,:));
    function [j,hc]=medir(z)
        [j,hc,td,vv,ee]=objetivo_chb(z,cfg); ne=ne+1;
        if hc==0 && j<best
            best=j; nb=nb+1;
            eventos(nb,:)=[ne,j,td,vv,ee,toc(reloj),z(:)'];
        end
    end
end

function [x,f,h,e,t]=llamar_algoritmo(metodo,obj,cfg)
lo=[0 0 0]; hi=[90 90 90];
switch metodo
    case 'DE'
        [x,f,h,e,t]=DE_71_eval(lo,hi,obj,cfg.Np,cfg.MaxEval,cfg.F,cfg.Cr);
    case 'TLBO'
        [x,f,h,e,t]=TLBO_71_eval(lo,hi,obj,cfg.Np,cfg.MaxEval,cfg.TF);
    case 'GWO'
        [x,f,h,e,t]=GWO_71_eval(lo,hi,obj,cfg.Np,cfg.MaxEval,cfg.a0);
    case 'AFTA'
        [x,f,h,e,t]=AFTA_71_eval(lo,hi,obj,cfg.Np,cfg.MaxEval,cfg.Td0,cfg.PpFactor);
    otherwise, error('Metodo desconocido.');
end
end

function [J,h,THD,V1,ErrorV]=objetivo_chb(x,cfg)
% Mismo modelo y penalizacion del original; admite tres fuentes diferentes.
h=0; THD=1e6; V1=0; ErrorV=1e6; J=1e12;
if numel(x)~=3 || any(~isfinite(x)) || ~(x(1)>0 && x(1)<x(2) && x(2)<x(3) && x(3)<90)
    h=100; return;
end
% Para el caso de fuentes iguales se conserva el orden de operaciones original.
if all(cfg.Vdc==cfg.Vdc(1))
    d=cfg.Vdc(1); V1=(4*d/pi)*(cosd(x(1))+cosd(x(2))+cosd(x(3)));
else
    V1=(4/pi)*sum(cfg.Vdc.*cosd(x));
end
s=0;
for n=3:2:cfg.Hmax
    if all(cfg.Vdc==cfg.Vdc(1))
        vn=(4*cfg.Vdc(1)/(n*pi))*(cosd(n*x(1))+cosd(n*x(2))+cosd(n*x(3)));
    else
        vn=4/(n*pi)*sum(cfg.Vdc.*cosd(n*x));
    end
    s=s+vn^2;
end
if V1<=0 || ~isfinite(V1), h=100; return; end
THD=100*sqrt(s)/abs(V1); ErrorV=abs(cfg.Vref-V1); J=THD+cfg.lambdaV*ErrorV;
if ~isfinite(J), J=1e12; h=100; end
end

function [n,v,mag,thd]=espectro_chb(x,cfg)
n=(1:2:cfg.Hmax)'; v=zeros(size(n));
for k=1:numel(n), v(k)=4/(n(k)*pi)*sum(cfg.Vdc.*cosd(n(k)*x)); end
mag=100*abs(v)/abs(v(1)); thd=sqrt(sum(mag(2:end).^2));
end

function T=resumir_chb(S)
R=S.resultados; filas=cell(numel(S.metodos),27);
for m=1:numel(S.metodos)
    A=R(strcmp(R.Metodo,S.metodos{m}),:); [j,i]=min(A.FuncionObjetivo_J);
    hit=A.AlcanzoObjetivo; e=A.EvaluacionesHastaObjetivo(hit); t=A.TiempoHastaObjetivo_s(hit);
    % ERT: reinicios independientes, exitos aportan esfuerzo; fallos presupuesto.
    % No es mediana incondicional ni imputacion de fallos como exitos.
    if any(hit)
        ert=(sum(e)+sum(~hit)*S.cfg.MaxEval)/sum(hit);
        ertT=(sum(t)+sum(A.TiempoInstrumentado_s(~hit)))/sum(hit);
    else, ert=Inf; ertT=Inf; end
    q=cuantil_chb(A.THD_pct,[.25 .75]);
    filas(m,:)={S.metodos{m},A.Alpha1_deg(i),A.Alpha2_deg(i),A.Alpha3_deg(i), ...
        j,mean(A.FuncionObjetivo_J),std(A.FuncionObjetivo_J),A.THD_pct(i), ...
        mean(A.THD_pct),std(A.THD_pct),median(A.THD_pct),q(2)-q(1), ...
        mean(A.ErrorV_V),max(A.ErrorV_V),mean(A.Tiempo_s),std(A.Tiempo_s), ...
        100*mean(A.ExitoFinal),100*mean(hit),mediana_vacia(e),mediana_vacia(t), ...
        ert,ertT,mean(A.TiempoAmortizado_us_eval), ...
        media_vacia(e),desv_vacia(e),media_vacia(t),desv_vacia(t)};
end
T=cell2table(filas,'VariableNames',{'Metodo','Alpha1_mejor','Alpha2_mejor','Alpha3_mejor', ...
    'J_min','J_media','J_desv','THD_mejor_pct','THD_media_pct','THD_desv_pct', ...
    'THD_mediana_pct','THD_IQR_pct','ErrorV_medio_V','ErrorV_max_V','Tiempo_medio_s', ...
    'Tiempo_desv_s','ExitoFinal_pct','AlcanzoObjetivo_pct','MedianaEvalSoloExitos', ...
    'MedianaTiempoSoloExitos_s','ERT_evaluaciones','ERT_tiempo_instrumentado_s','TiempoAmortizado_us_eval', ...
    'MediaEvalSoloExitos','DesvEvalSoloExitos','MediaTiempoSoloExitos_s','DesvTiempoSoloExitos_s'});
end
function v=media_vacia(x)
if isempty(x), v=NaN; else, v=mean(x); end
end
function v=desv_vacia(x)
if numel(x)<2, v=NaN; else, v=std(x); end
end
function v=mediana_vacia(x)
if isempty(x), v=NaN; else, v=median(x); end
end
function q=cuantil_chb(x,p)
x=sort(x(:)); q=nan(size(p));
if isempty(x), return; end
for i=1:numel(p)
    t=1+(numel(x)-1)*p(i); a=floor(t); b=ceil(t);
    q(i)=x(a)+(t-a)*(x(b)-x(a));
end
end

function out=estadistica_chb(S)
% Bloques = semillas; tratamientos = algoritmos del MISMO punto operativo.
% No agrupar voltajes, poblaciones o semillas como problemas independientes.
R=numel(S.cfg.Semillas); M=numel(S.metodos);
out=struct('omnibus',table(),'pares',table());
if M<2 || R<2, return; end
campos={'J','THD','ErrorV','Tiempo_s'}; etiquetas={'J','THD_pct','ErrorV_V','Tiempo_s'};
filaO=cell(4,7); filaP=cell(4*nchoosek(M,2),11); z=0;
for k=1:4
    X=zeros(R,M);
    for m=1:M
        for r=1:R, X(r,m)=S.runs{r,m}.(campos{k}); end
    end
    quantum=S.cfg.Quantum(k); Xq=round(X/quantum)*quantum;
    [Q,p,W]=friedman_chb(Xq);
    filaO(k,:)={etiquetas{k},R,M,Q,p,W,quantum};
    for a=1:M-1
        for b=a+1:M
            d=round((X(:,a)-X(:,b))/quantum)*quantum;
            [pv,rbc,n]=rangos_signo_exacto(d);
            z=z+1;
            filaP(z,:)={etiquetas{k},S.metodos{a},S.metodos{b},pv,rbc,n, ...
                median(X(:,a)-X(:,b)),mean(X(:,a)<X(:,b)-quantum/2),quantum,p,signos_exacto(d)};
        end
    end
end
O=cell2table(filaO,'VariableNames',{'Metrica','Bloques','Metodos','Chi2_Friedman', ...
    'p_Friedman_asintotica','Kendall_W','Quantum'});
O.p_Holm_4_metricas=holm_chb(O.p_Friedman_asintotica);
P=cell2table(filaP,'VariableNames',{'Metrica','Metodo_A','Metodo_B','p_Wilcoxon_exacta', ...
    'r_biserial_A_menos_B','ParesNoNulos','MedianaDiferencia_A_menos_B', ...
    'Fraccion_A_menor_B','Quantum','p_Friedman_metrica','p_Signos_exacta'});
P.p_Holm_por_metrica=zeros(height(P),1);
for k=1:4
    ix=strcmp(P.Metrica,etiquetas{k});
    P.p_Holm_por_metrica(ix)=holm_chb(P.p_Wilcoxon_exacta(ix));
end
P.p_Holm_todas_comparaciones=holm_chb(P.p_Wilcoxon_exacta);
P.p_Signos_Holm_global=holm_chb(P.p_Signos_exacta);
P.Rechaza_005_con_Holm_global=P.p_Holm_todas_comparaciones<=.05;
out.omnibus=O; out.pares=P;
end

function [rank,ties]=rangos_chb(x)
x=x(:); [v,ix]=sort(x); rank=zeros(size(x)); ties=0; i=1;
while i<=numel(x)
    j=i; while j<numel(x) && v(j+1)==v(i), j=j+1; end
    rank(ix(i:j))=(i+j)/2; t=j-i+1; ties=ties+t^3-t; i=j+1;
end
end
function [Q,p,W]=friedman_chb(X)
[n,k]=size(X); rank=zeros(n,k); ties=0;
for i=1:n, [rr,tt]=rangos_chb(X(i,:)); rank(i,:)=rr'; ties=ties+tt; end
C=1-ties/(n*(k^3-k));
if C<=eps, Q=0; p=1; W=0; return; end
Q=max(0,(12/(n*k*(k+1))*sum(sum(rank,1).^2)-3*n*(k+1))/C);
p=gammainc(Q/2,(k-1)/2,'upper'); W=Q/(n*(k-1));
end
function [p,rbc,n]=rangos_signo_exacto(d)
% Wilcoxon pareado bilateral, ceros excluidos; distribucion exacta de signos.
% Empates admitidos mediante rangos medios escalados por dos (enteros).
% Supuesto: diferencias independientes entre semillas y simetricas bajo H0.
d=d(:); d=d(d~=0); n=numel(d);
if n==0, p=1; rbc=0; return; end
[r,~]=rangos_chb(abs(d)); w=round(2*r);
S=sum(w); observado=sum(w(d>0)); prob=1;
for i=1:n
    siguiente=zeros(numel(prob)+w(i),1);
    siguiente(1:numel(prob))=siguiente(1:numel(prob))+.5*prob;
    siguiente(1+w(i):w(i)+numel(prob))=siguiente(1+w(i):w(i)+numel(prob))+.5*prob;
    prob=siguiente;
end
s=(0:S)'; p=min(1,sum(prob(abs(2*s-S)>=abs(2*observado-S))));
rbc=sum(sign(d).*r)/sum(r); % negativo: A tiende a ser menor/mejor.
end
function p=signos_exacto(d)
% Alternativa pareada sin supuesto de simetria; excluye diferencias nulas.
d=d(d~=0); n=numel(d);
if n==0, p=1; return; end
k=min(sum(d>0),sum(d<0)); j=(0:k)';
p=min(1,2*sum(exp(gammaln(n+1)-gammaln(j+1)-gammaln(n-j+1)-n*log(2))));
end
function ajustado=holm_chb(p)
p=p(:); [ordenado,ix]=sort(p); n=numel(p);
a=cummax((n-(1:n)'+1).*ordenado); ajustado=zeros(n,1); ajustado(ix)=min(a,1);
end

function exportar_caso(S,carpeta)
writetable(S.resultados,fullfile(carpeta,'resultados_corridas.csv'));
writetable(S.resumen,fullfile(carpeta,'resumen_comparativo.csv'));
if ~isempty(S.estadistica.omnibus)
    writetable(S.estadistica.omnibus,fullfile(carpeta,'estadistica_Friedman.csv'));
    writetable(S.estadistica.pares,fullfile(carpeta,'estadistica_pares_Wilcoxon_Holm.csv'));
end
M=numel(S.metodos); R=numel(S.cfg.Semillas); E=S.E;
T=table(E,'VariableNames',{'Evaluaciones'}); histPartes=cell(R*M,1); eventosPartes=cell(R*M,1); z=0;
for m=1:M
    C=S.conv(:,:,m);
    T.([S.metodos{m} '_J_media'])=mean(C,2);
    T.([S.metodos{m} '_J_desv'])=std(C,0,2);
    T.([S.metodos{m} '_J_mediana'])=median(C,2);
    for r=1:R
        z=z+1; n=numel(E); u=S.runs{r,m};
        histPartes{z}=table(repmat(S.metodos(m),n,1),repmat(S.cfg.Semillas(r),n,1),E,u.hist(:), ...
            'VariableNames',{'Metodo','Semilla','Evaluaciones','Mejor_J'});
        ev=u.eventos; n=size(ev,1);
        A=array2table(ev,'VariableNames',{'Evaluacion','J','THD_pct','V1_V','ErrorV_V', ...
            'TiempoInstrumentado_s','Alpha1_deg','Alpha2_deg','Alpha3_deg'});
        A.Metodo=repmat(S.metodos(m),n,1); A.Semilla=repmat(S.cfg.Semillas(r),n,1);
        eventosPartes{z}=A;
    end
end
writetable(T,fullfile(carpeta,'convergencia_J_resumen.csv'));
writetable(vertcat(histPartes{:}),fullfile(carpeta,'convergencia_por_corrida.csv'));
writetable(vertcat(eventosPartes{:}),fullfile(carpeta,'mejoras_evaluacion_exacta.csv'));
filas=cell(M,10);
for m=1:M
    A=S.resultados(strcmp(S.resultados.Metodo,S.metodos{m}),:);
    [j,i]=min(A.FuncionObjetivo_J); x=[A.Alpha1_deg(i) A.Alpha2_deg(i) A.Alpha3_deg(i)];
    [n,v,mag,thd]=espectro_chb(x,S.cfg);
    assert(abs(thd-A.THD_pct(i))<1e-8 && abs(abs(v(1))-A.V1_V(i))<1e-8, ...
        'Espectro y optimizacion no coinciden.');
    D=table(n,v,mag,'VariableNames',{'Orden_armonico','Vn_pico_V','Magnitud_pct_V1'});
    writetable(D,fullfile(carpeta,['datos_espectro_' S.metodos{m} '.csv']));
    [dom,k]=max(mag(2:end));
    filas(m,:)={S.metodos{m},A.Semilla(i),x(1),x(2),x(3),j,abs(v(1)),thd,n(k+1),dom};
end
F=cell2table(filas,'VariableNames',{'Metodo','Semilla','Alpha1_deg','Alpha2_deg','Alpha3_deg', ...
    'J','V1_pico_V','THD_pct','Orden_dominante','Magnitud_dominante_pct'});
writetable(F,fullfile(carpeta,'resumen_espectros.csv'));
% Relevancia numerica: diferencias de mejores soluciones; no prueba fisica.
delta=max(F.THD_pct)-min(F.THD_pct);
fid=fopen(fullfile(carpeta,'interpretacion_y_alcance.txt'),'w');
fprintf(fid,'Caso: %s\n',S.caso);
fprintf(fid,'Referencia empirica J = %.15g; limite J = %.15g; error <= %.6g V.\n',S.Jref,S.Jref+S.cfg.TolJ,S.cfg.TolV);
fprintf(fid,'Separacion maxima THD de mejores soluciones = %.12g puntos porcentuales.\n',delta);
fprintf(fid,'Separacion relativa al mejor THD = %.12g %% .\n',100*delta/min(F.THD_pct));
fprintf(fid,'Equivalente a V1 comun de referencia: %.12g V RMS armonicos (modelo truncado).\n',S.cfg.Vref/sqrt(2)*delta/100);
fprintf(fid,['La cifra anterior supone V1 comun; no es una medicion fisica.\n' ...
    'THD calculada con armonicos impares 3..Hmax; no THD de banda infinita.\n' ...
    'La referencia de exito es retrospectiva, obtenida del mismo caso.\n' ...
    'Medianas hasta objetivo: solo exitos; leer junto a tasa de alcance y ERT.\n' ...
    'ECDF de alcance usa todas las corridas; los fallos no llegan artificialmente al 100%%.\n' ...
    'Tiempo amortizado = tiempo total/MaxEval, NO costo aislado del objetivo.\n' ...
    'J es la metrica principal; THD, error y tiempo son analisis secundarios.\n' ...
    'Friedman: bloques por semilla; p asintotica corregida por empates.\n' ...
    'Wilcoxon: distribucion exacta de signos de rangos, ceros excluidos.\n' ...
    'Wilcoxon supone simetria de diferencias; examinar diferencias_pareadas_J.png.\n' ...
    'Se incluye prueba exacta de signos como analisis de sensibilidad sin simetria.\n' ...
    'Holm por metrica y Holm global se reportan por separado; evitar elegir el menor p.\n' ...
    'R biserial negativo favorece A (menor valor); W de Kendall mide concordancia de rangos.\n' ...
    'El redondeo estadistico elimina diferencias de precision numerica; no altera CSV.\n' ...
    'Una diferencia significativa no demuestra ventaja ingenieril.\n' ...
    'Inferencia limitada a este caso y estas implementaciones, no a todos los inversores.\n']);
if S.cfg.EsPrueba, fprintf(fid,'PRUEBA CORTA: NO USAR ESTOS RESULTADOS EN EL ARTICULO.\n'); end
fclose(fid);
end

function graficas_chb(S,carpeta)
g=S.cfg.grafica; M=numel(S.metodos); R=numel(S.cfg.Semillas);
col=colores_chb(S.metodos,g.Colores);
% Promedio y dispersion observada: banda de +/- SD, NO intervalo de confianza.
f=figura_chb(g); ax=axes('Parent',f); hold(ax,'on'); hh=gobjects(M,1);
for m=1:M
    C=S.conv(:,:,m); y=mean(C,2); sd=std(C,0,2); x=S.E;
    fill(ax,[x;flipud(x)],[max(y-sd,eps);flipud(y+sd)],.83+.17*col(m,:), ...
        'EdgeColor','none','HandleVisibility','off');
    hh(m)=plot(ax,x,y,'Color',col(m,:),'LineWidth',2);
end
set(ax,'YScale','log'); xlabel(ax,'Objective-function evaluations'); ylabel(ax,'Best-so-far J');
title(ax,'Mean convergence with descriptive SD bands'); legend(ax,hh,S.metodos,'Location','best');
guardar_chb(f,carpeta,'convergencia_media_J',g);
% Brecha respecto del minimo observado para distinguir convergencia final.
f=figura_chb(g); ax=axes('Parent',f); hold(ax,'on');
for m=1:M
    y=median(S.conv(:,:,m),2)-S.Jref;
    plot(ax,S.E,max(y,1e-12),'Color',col(m,:),'LineWidth',2);
end
set(ax,'YScale','log'); xlabel(ax,'Objective-function evaluations');
ylabel(ax,'Median best J - observed reference'); title(ax,'Convergence gap (display floor: 10^{-12})');
legend(ax,S.metodos,'Location','best'); guardar_chb(f,carpeta,'convergencia_brecha_J',g);
campos={'THD','ErrorV','J','Tiempo_s'};
etiquetas={'Final THD (%)','Absolute fundamental error (V)','Final objective J','Runtime without detailed logging (s)'};
nombres={'dispersion_THD','dispersion_error_V1','dispersion_J','dispersion_tiempo'};
if ~S.cfg.MedirSinRegistro, etiquetas{4}='Instrumented runtime (s)'; end
for k=1:4
    D=zeros(M,R);
    for m=1:M, for r=1:R, D(m,r)=S.runs{r,m}.(campos{k}); end, end
    f=figura_chb(g); cajas_chb(D,S.metodos,col); ylabel(etiquetas{k}); xlabel('Algorithm');
    title(sprintf('Distribution over %d runs per algorithm',R)); guardar_chb(f,carpeta,nombres{k},g);
end
f=figura_chb(g); ax=axes('Parent',f);
b=bar(ax,1:M,S.resumen.Tiempo_medio_s,.65,'FaceColor','flat'); b.CData=col; hold(ax,'on');
errorbar(ax,1:M,S.resumen.Tiempo_medio_s,S.resumen.Tiempo_desv_s,'k.', ...
    'LineWidth',1.3,'CapSize',10);
set(ax,'XTick',1:M,'XTickLabel',S.metodos); xlabel(ax,'Algorithm'); ylabel(ax,'Mean runtime +/- SD (s)');
title(ax,'Total computational cost'); guardar_chb(f,carpeta,'tiempos_media_SD',g);
% Curvas de alcance empírico, denominador = todas las corridas, incluidos fallos.
f=figura_chb(g); ax=axes('Parent',f); hold(ax,'on'); hh=gobjects(M,1);
for m=1:M
    A=S.resultados(strcmp(S.resultados.Metodo,S.metodos{m}),:);
    e=sort(A.EvaluacionesHastaObjetivo(A.AlcanzoObjetivo));
    xx=[0;e;S.cfg.MaxEval]; yy=[0;(1:numel(e))'/R;numel(e)/R];
    hh(m)=stairs(ax,xx,100*yy,'Color',col(m,:),'LineWidth',2);
end
xlabel(ax,'Objective-function evaluations'); ylabel(ax,'Runs reaching the target (%)'); ylim(ax,[0 105]);
title(ax,'Per-run attainment of the empirical target'); legend(ax,hh,S.metodos,'Location','southeast');
guardar_chb(f,carpeta,'alcance_objetivo_evaluaciones',g);
f=figura_chb(g); ax=axes('Parent',f); hold(ax,'on'); hh=gobjects(M,1);
tmax=max(S.resultados.TiempoInstrumentado_s);
for m=1:M
    A=S.resultados(strcmp(S.resultados.Metodo,S.metodos{m}),:);
    tt=sort(A.TiempoHastaObjetivo_s(A.AlcanzoObjetivo));
    hh(m)=stairs(ax,[0;tt;tmax],100*[0;(1:numel(tt))'/R;numel(tt)/R], ...
        'Color',col(m,:),'LineWidth',2);
end
xlabel(ax,'Instrumented elapsed time (s)'); ylabel(ax,'Runs reaching the target (%)'); ylim(ax,[0 105]);
title(ax,'Per-run time to the empirical target'); legend(ax,hh,S.metodos,'Location','southeast');
guardar_chb(f,carpeta,'alcance_objetivo_tiempo',g);
% Espectros y formas de onda de la MISMA corrida seleccionada por minimo J.
for m=1:M
    A=S.resultados(strcmp(S.resultados.Metodo,S.metodos{m}),:);
    [~,i]=min(A.FuncionObjetivo_J); x=[A.Alpha1_deg(i) A.Alpha2_deg(i) A.Alpha3_deg(i)];
    [n,v,mag,thd]=espectro_chb(x,S.cfg);
    f=figura_chb(g); a1=subplot(3,1,1,'Parent',f);
    bar(a1,1,100,.65,'FaceColor',col(m,:)); xlim(a1,[0 S.cfg.Hmax+1]); ylim(a1,[0 115]);
    set(a1,'XTick',[],'YTick',[0 100]); ylabel(a1,'Fund. (%)');
    title(a1,sprintf('%s: analytical spectrum, THD = %.6f%%',S.metodos{m},thd));
    a2=subplot(3,1,2:3,'Parent',f);
    bar(a2,n(2:end),mag(2:end),.65,'FaceColor',col(m,:));
    xlim(a2,[0 S.cfg.Hmax+1]); ylim(a2,[0 max(mag(2:end))*1.2]);
    set(a2,'XTick',unique([3:4:S.cfg.Hmax S.cfg.Hmax]));
    xlabel(a2,'Harmonic order n'); ylabel(a2,'Magnitude (% of V_1)');
    guardar_chb(f,carpeta,['espectro_' S.metodos{m}],g);
    % Transiciones exactas, sin inferir datos experimentales.
    al=deg2rad(x); theta=sort(unique([0 al pi-fliplr(al) pi pi+al 2*pi-fliplr(al) 2*pi]));
    mid=(theta(1:end-1)+theta(2:end))/2;
    w=voltaje_ideal(mid,x,S.cfg); w=[w 0];
    f=figura_chb(g); ax=axes('Parent',f); hold(ax,'on');
    stairs(ax,theta,w,'Color',col(m,:),'LineWidth',1.8);
    t=linspace(0,2*pi,1500); plot(ax,t,abs(v(1))*sin(t),'k--','LineWidth',1.2);
    set(ax,'XTick',0:pi/2:2*pi,'XTickLabel',{'0','\pi/2','\pi','3\pi/2','2\pi'});
    xlabel(ax,'Electrical angle (rad)'); ylabel(ax,'Output voltage (V)');
    title(ax,[S.metodos{m} ': ideal analytical voltage']);
    legend(ax,{'Stepped voltage','Fundamental'},'Location','best');
    guardar_chb(f,carpeta,['onda_analitica_' S.metodos{m}],g);
    writetable(table(theta(:),w(:),'VariableNames',{'Angulo_rad','Voltaje_V'}), ...
        fullfile(carpeta,['datos_onda_' S.metodos{m} '.csv']));
end
% Diagnostico de simetria de diferencias: pares de J, datos completos en CSV.
if M>1
    f=figura_chb(g); set(f,'Position',[1 1 24 18]); z=0; K=nchoosek(M,2);
    for a=1:M-1
        for b=a+1:M
            z=z+1; ax=subplot(ceil(K/2),2,z,'Parent',f);
            d=zeros(R,1);
            for r=1:R, d(r)=S.runs{r,a}.J-S.runs{r,b}.J; end
            histogram(ax,d,'FaceColor',[.3 .4 .5]); xlabel(ax,'J_A - J_B'); ylabel(ax,'Runs');
            title(ax,[S.metodos{a} ' - ' S.metodos{b}]);
        end
    end
    guardar_chb(f,carpeta,'diferencias_pareadas_J',g);
end
end

function v=voltaje_ideal(theta,x,cfg)
q=mod(theta,pi); q=min(q,pi-q); v=zeros(size(theta));
for k=1:3, v=v+cfg.Vdc(k)*(q>=deg2rad(x(k))); end
v=v.*(1-2*(mod(theta,2*pi)>=pi));
end
function col=colores_chb(metodos,todos)
base={'DE','TLBO','GWO','AFTA'}; col=zeros(numel(metodos),3);
for m=1:numel(metodos), col(m,:)=todos(strcmp(base,metodos{m}),:); end
end
function f=figura_chb(g)
f=figure('Color','w','Visible',g.Visible,'Units','centimeters', ...
    'Position',[1 1 g.Ancho_cm g.Alto_cm],'PaperPositionMode','auto');
end
function guardar_chb(f,carpeta,nombre,g)
axs=findall(f,'Type','axes');
for i=1:numel(axs)
    a=axs(i); set(a,'FontName','Arial','FontSize',g.Fuente,'LineWidth',1,'Box','on');
    grid(a,'on'); set(a.XLabel,'FontSize',g.Etiquetas); set(a.YLabel,'FontSize',g.Etiquetas);
    set(a.Title,'FontSize',g.Titulo,'FontWeight','bold');
end
leg=findall(f,'Type','legend'); set(leg,'FontSize',g.Leyenda,'Box','off');
drawnow;
if g.Exportar
    savefig(f,fullfile(carpeta,[nombre '.fig']));
    % print mantiene tamano fisico; PNG es vista rapida, TIFF entrega editorial.
    print(f,fullfile(carpeta,[nombre '.tif']),'-dtiff',['-r' num2str(g.DPI)]);
    print(f,fullfile(carpeta,[nombre '.png']),'-dpng','-r160');
    try
        exportgraphics(f,fullfile(carpeta,[nombre '.pdf']),'ContentType','vector','BackgroundColor','white');
    catch
        set(f,'PaperUnits','centimeters'); pp=get(f,'Position');
        set(f,'PaperSize',pp(3:4),'PaperPosition',[0 0 pp(3:4)]);
        print(f,fullfile(carpeta,[nombre '.pdf']),'-dpdf','-painters');
    end
end
if g.Cerrar, close(f); end
end
function cajas_chb(D,nombres,col)
hold on; M=size(D,1);
for m=1:M
    v=D(m,:); q=cuantil_chb(v,[.25 .5 .75]); iq=q(3)-q(1);
    dentro=v(v>=q(1)-1.5*iq & v<=q(3)+1.5*iq); a=min(dentro); b=max(dentro);
    patch(m+[-.28 .28 .28 -.28],[q(1) q(1) q(3) q(3)],.75+.25*col(m,:), ...
        'EdgeColor',col(m,:),'LineWidth',1.4);
    plot(m+[-.28 .28],[q(2) q(2)],'Color',col(m,:),'LineWidth',2);
    plot([m m],[a q(1)],'Color',col(m,:)); plot([m m],[q(3) b],'Color',col(m,:));
    plot(m+[-.14 .14],[a a],'Color',col(m,:)); plot(m+[-.14 .14],[b b],'Color',col(m,:));
    % Desplazamiento determinista: no cambia el generador aleatorio.
    plot(m+linspace(-.16,.16,numel(v)),v,'.','Color',col(m,:),'MarkerSize',8);
end
xlim([.4 M+.6]); set(gca,'XTick',1:M,'XTickLabel',nombres);
end

function info=entorno_chb()
info.MATLAB=version; info.Arquitectura=computer; info.Toolboxes=ver;
info.Fecha=datestr(now,31); info.Paralelismo='Ejecucion serial; sin parfor ni GPU';
info.CPU='No detectada: completar manualmente'; info.RAM_GB=NaN;
info.Hilos='No detectados';
try, info.Hilos=maxNumCompThreads; catch, end
if ispc
    info.CPU=getenv('PROCESSOR_IDENTIFIER'); [~,info.OS]=system('ver');
    try
        [s,cpu]=system('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name"');
        if s==0, info.CPU=strtrim(cpu); end
        [~,mem]=memory; info.RAM_GB=mem.PhysicalMemory.Total/1024^3;
    catch
    end
elseif ismac
    [~,info.OS]=system('sw_vers'); [~,info.CPU]=system('sysctl -n machdep.cpu.brand_string');
    [~,ram]=system('sysctl -n hw.memsize'); info.RAM_GB=str2double(strtrim(ram))/1024^3;
else
    [~,info.OS]=system('uname -sr');
    try
        c=fileread('/proc/cpuinfo'); t=regexp(c,'model name\s*:\s*([^\n]+)','tokens','once');
        if ~isempty(t), info.CPU=t{1}; end
        c=fileread('/proc/meminfo'); t=regexp(c,'MemTotal:\s*(\d+)','tokens','once');
        if ~isempty(t), info.RAM_GB=str2double(t{1})/1024^2; end
    catch
    end
end
end

function autoprueba_chb(cfg)
fprintf('Autopruebas numericas: no genera resultados publicables.\n');
x=[10.157139 31.056272 58.982498];
[j,h,td,v,er]=objetivo_chb(x,cfg); [~,vv,~,tt]=espectro_chb(x,cfg);
assert(h==0 && abs(td-11.66910789795)<1e-7);
assert(abs(td-tt)<1e-10 && abs(v-vv(1))<1e-10 && abs(j-td-10*er)<1e-12);
X=reparar_angulos_71([0 0 0;90 90 90;40 20 30],[0 0 0],[90 90 90]);
assert(all(all(diff(X,1,2)>0)) && all(X(:,1)>0) && all(X(:,3)<90));
[p,r,n]=rangos_signo_exacto([1 2 3 4]); assert(abs(p-.125)<1e-14 && r==1 && n==4);
[p,r,n]=rangos_signo_exacto([0 0 0]); assert(p==1 && r==0 && n==0);
[Q,p,W]=friedman_chb(repmat([1 2 3 4],5,1));
assert(abs(Q-15)<1e-12 && abs(W-1)<1e-12 && p<.01);
assert(abs(signos_exacto([1 1 1 1])-.125)<1e-14);
a=holm_chb([.01 .04 .03]); assert(max(abs(a-[.03;.06;.06]))<1e-14);
q=cfg; q.Np=10; q.MaxEval=50;
for m={'DE','TLBO','GWO','AFTA'}
    u=corrida_instrumentada(m{1},q,123); [plain,~]=corrida_sin_registro(m{1},q,123);
    assert(abs(u.J-plain.J)<1e-12 && max(abs(u.x-plain.x))<1e-12);
    assert(u.evalHist(end)==q.MaxEval && numel(u.hist)==5);
    assert(all(diff(u.eventos(:,1))>0) && all(diff(u.eventos(:,2))<0));
    fprintf('  %s: presupuesto, registro y reproducibilidad correctos.\n',m{1});
end
fprintf('Autopruebas superadas. Ejecute CHB_UNIFICADO(''prueba'') para revisar graficas/exportacion.\n');
end


function [bestsol, bestfit, hist, evalHist, tiempo] = DE_71_eval( ...
    limInferior, Sup, THDFUN, Np, MaxEval, F, Cr)
% Differential Evolution DE/rand/1/bin con presupuesto de evaluaciones.

inicio = tic;
limInferior = limInferior(:)'; Sup = Sup(:)';
D = numel(limInferior);
if Np < 4, error('DE requiere al menos cuatro individuos.'); end

P = limInferior + rand(Np,D).*(Sup-limInferior);
P = reparar_angulos_71(P, limInferior, Sup);
Fit = inf(Np,1); H = inf(Np,1);
for i=1:Np, [Fit(i),H(i)] = evaluar_71(THDFUN,P(i,:)); end

evals = Np;
hist = mejor_valor_71(Fit,H);
evalHist = evals;

while evals + Np <= MaxEval
    for i = 1:Np
        candidatos = [1:i-1, i+1:Np];
        idx = candidatos(randperm(Np-1,3));
        V = P(idx(1),:) + F*(P(idx(2),:)-P(idx(3),:));
        V = reparar_angulos_71(V, limInferior, Sup);

        U = P(i,:);
        jrand = randi(D);
        mascara = rand(1,D) <= Cr;
        mascara(jrand) = true;
        U(mascara) = V(mascara);
        U = reparar_angulos_71(U, limInferior, Sup);

        [fNew,hNew] = evaluar_71(THDFUN,U);
        if es_mejor_71(fNew,hNew,Fit(i),H(i))
            P(i,:) = U; Fit(i) = fNew; H(i) = hNew;
        end
    end
    evals = evals + Np;
    hist(end+1,1) = mejor_valor_71(Fit,H); %#ok<AGROW>
    evalHist(end+1,1) = evals; %#ok<AGROW>
end

ind = mejor_indice_71(Fit,H);
bestsol = P(ind,:); bestfit = Fit(ind);
tiempo = toc(inicio);
end




function [bestsol, bestfit, hist, evalHist, tiempo] = TLBO_71_eval( ...
    limInferior, Sup, THDFUN, Np, MaxEval, TFconfig)
% TLBO con registro despues de cada lote de Np evaluaciones. Cada ciclo
% completo contiene una fase del maestro y una fase del estudiante.

inicio = tic;
limInferior = limInferior(:)'; Sup = Sup(:)'; D = numel(limInferior);
if Np < 2, error('TLBO requiere al menos dos individuos.'); end

P = limInferior + rand(Np,D).*(Sup-limInferior);
P = reparar_angulos_71(P,limInferior,Sup);
Fit = inf(Np,1); H = inf(Np,1);
for i=1:Np, [Fit(i),H(i)] = evaluar_71(THDFUN,P(i,:)); end

evals = Np;
hist = mejor_valor_71(Fit,H);
evalHist = evals;

while evals + Np <= MaxEval
    %% Fase del maestro
    ind = mejor_indice_71(Fit,H);
    Teacher = P(ind,:);
    Media = mean(P,1);
    if TFconfig==0, TF = randi([1 2]); else, TF=TFconfig; end
    for i=1:Np
        Xnew = P(i,:) + rand(1,D).*(Teacher-TF*Media);
        Xnew = reparar_angulos_71(Xnew,limInferior,Sup);
        [fNew,hNew] = evaluar_71(THDFUN,Xnew);
        if es_mejor_71(fNew,hNew,Fit(i),H(i))
            P(i,:) = Xnew; Fit(i)=fNew; H(i)=hNew;
        end
    end
    evals = evals + Np;
    hist(end+1,1) = mejor_valor_71(Fit,H); %#ok<AGROW>
    evalHist(end+1,1) = evals; %#ok<AGROW>
    if evals + Np > MaxEval, break; end

    %% Fase del estudiante
    for i=1:Np
        j = randi(Np);
        while j==i, j=randi(Np); end
        if es_mejor_71(Fit(i),H(i),Fit(j),H(j))
            Xnew = P(i,:) + rand(1,D).*(P(i,:)-P(j,:));
        else
            Xnew = P(i,:) + rand(1,D).*(P(j,:)-P(i,:));
        end
        Xnew = reparar_angulos_71(Xnew,limInferior,Sup);
        [fNew,hNew] = evaluar_71(THDFUN,Xnew);
        if es_mejor_71(fNew,hNew,Fit(i),H(i))
            P(i,:) = Xnew; Fit(i)=fNew; H(i)=hNew;
        end
    end
    evals = evals + Np;
    hist(end+1,1) = mejor_valor_71(Fit,H); %#ok<AGROW>
    evalHist(end+1,1) = evals; %#ok<AGROW>
end

ind = mejor_indice_71(Fit,H);
bestsol = P(ind,:); bestfit = Fit(ind);
tiempo = toc(inicio);
end




function [bestsol, bestfit, hist, evalHist, tiempo] = GWO_71_eval( ...
    limInferior, Sup, THDFUN, Np, MaxEval, a0)
% Variante suministrada de GWO: conserva tres lideres historicos.

inicio = tic;
limInferior = limInferior(:)'; Sup = Sup(:)'; D = numel(limInferior);
if Np < 3, error('GWO requiere al menos tres individuos.'); end

P = limInferior + rand(Np,D).*(Sup-limInferior);
P = reparar_angulos_71(P,limInferior,Sup);

AlphaPos=zeros(1,D); BetaPos=zeros(1,D); DeltaPos=zeros(1,D);
AlphaFit=inf; BetaFit=inf; DeltaFit=inf;
AlphaH=inf; BetaH=inf; DeltaH=inf;

for i=1:Np
    [f,h] = evaluar_71(THDFUN,P(i,:));
    [AlphaPos,AlphaFit,AlphaH,BetaPos,BetaFit,BetaH, ...
        DeltaPos,DeltaFit,DeltaH] = actualizar_lideres( ...
        P(i,:),f,h,AlphaPos,AlphaFit,AlphaH,BetaPos,BetaFit,BetaH, ...
        DeltaPos,DeltaFit,DeltaH);
end

evals=Np; hist=AlphaFit; evalHist=evals;
NumeroLotes = floor(MaxEval/Np)-1;
lote = 0;

while evals + Np <= MaxEval
    lote = lote+1;
    if NumeroLotes <= 1
        a=0;
    else
        a=a0-a0*(lote-1)/(NumeroLotes-1);
    end

    NuevaP=zeros(Np,D);
    for i=1:Np
        X=P(i,:);
        r1=rand(1,D); r2=rand(1,D);
        A1=2*a.*r1-a; C1=2.*r2;
        X1=AlphaPos-A1.*abs(C1.*AlphaPos-X);
        r1=rand(1,D); r2=rand(1,D);
        A2=2*a.*r1-a; C2=2.*r2;
        X2=BetaPos-A2.*abs(C2.*BetaPos-X);
        r1=rand(1,D); r2=rand(1,D);
        A3=2*a.*r1-a; C3=2.*r2;
        X3=DeltaPos-A3.*abs(C3.*DeltaPos-X);
        NuevaP(i,:)=(X1+X2+X3)/3;
    end
    P=reparar_angulos_71(NuevaP,limInferior,Sup);

    for i=1:Np
        [f,h]=evaluar_71(THDFUN,P(i,:));
        [AlphaPos,AlphaFit,AlphaH,BetaPos,BetaFit,BetaH, ...
            DeltaPos,DeltaFit,DeltaH] = actualizar_lideres( ...
            P(i,:),f,h,AlphaPos,AlphaFit,AlphaH,BetaPos,BetaFit,BetaH, ...
            DeltaPos,DeltaFit,DeltaH);
    end
    evals=evals+Np;
    hist(end+1,1)=AlphaFit; %#ok<AGROW>
    evalHist(end+1,1)=evals; %#ok<AGROW>
end

bestsol=AlphaPos; bestfit=AlphaFit; tiempo=toc(inicio);
end

function [AP,AF,AH,BP,BF,BH,DP,DF,DH] = actualizar_lideres( ...
    x,f,h,AP,AF,AH,BP,BF,BH,DP,DF,DH)
if es_mejor_71(f,h,AF,AH)
    DP=BP; DF=BF; DH=BH;
    BP=AP; BF=AF; BH=AH;
    AP=x; AF=f; AH=h;
elseif es_mejor_71(f,h,BF,BH)
    DP=BP; DF=BF; DH=BH;
    BP=x; BF=f; BH=h;
elseif es_mejor_71(f,h,DF,DH)
    DP=x; DF=f; DH=h;
end
end




function [bestsol, bestfit, hist, evalHist, tiempo] = AFTA_71_eval( ...
    limInferior, Sup, THDFUN, Np, MaxEval, Td0, PpFactor)
% Implementacion AFTA suministrada por el autor; parametros configurables.

inicio=tic;
limInferior=limInferior(:)'; Sup=Sup(:)'; D=numel(limInferior);
if Np<2, error('AFTA requiere al menos dos individuos.'); end

P=limInferior+rand(Np,D).*(Sup-limInferior);
P=reparar_angulos_71(P,limInferior,Sup);
Fit=inf(Np,1); H=inf(Np,1);
for i=1:Np, [Fit(i),H(i)]=evaluar_71(THDFUN,P(i,:)); end

Pbest=P; Fbest=Fit; Hbest=H;
ind=mejor_indice_71(Fbest,Hbest);
Gbest=Pbest(ind,:); Gfit=Fbest(ind); Gh=Hbest(ind);
evals=Np; hist=Gfit; evalHist=evals;
NumeroLotes=floor(MaxEval/Np)-1;
lote=0;

while evals+Np<=MaxEval
    lote=lote+1;
    razon=lote/max(NumeroLotes,1);
    Pp=PpFactor*log(2.75*razon^0.1);
    Td=Td0*exp(-2*razon^2);
    NuevaP=zeros(Np,D);

    for i=1:Np
        seguidor=randi(Np);
        while seguidor==i, seguidor=randi(Np); end
        direccion=sign(rand-0.5);
        if direccion==0, direccion=1; end
        movimiento=Td*(Pbest(i,:)-P(i,:))*rand + ...
            Td*(P(i,:)-Pbest(seguidor,:))*rand;

        if rand>=0.5
            if rand>Pp
                Xnew=Gbest+movimiento*direccion;
            else
                Xnew=limInferior+Td*(Sup-limInferior).*rand(1,D);
            end
        else
            Xnew=Gbest-movimiento*direccion;
        end
        NuevaP(i,:)=Xnew;
    end

    P=reparar_angulos_71(NuevaP,limInferior,Sup);
    for i=1:Np
        [Fit(i),H(i)]=evaluar_71(THDFUN,P(i,:));
        if es_mejor_71(Fit(i),H(i),Fbest(i),Hbest(i))
            Pbest(i,:)=P(i,:); Fbest(i)=Fit(i); Hbest(i)=H(i);
        end
    end
    ind=mejor_indice_71(Fbest,Hbest);
    if es_mejor_71(Fbest(ind),Hbest(ind),Gfit,Gh)
        Gbest=Pbest(ind,:); Gfit=Fbest(ind); Gh=Hbest(ind);
    end
    evals=evals+Np;
    hist(end+1,1)=Gfit; %#ok<AGROW>
    evalHist(end+1,1)=evals; %#ok<AGROW>
end

bestsol=Gbest; bestfit=Gfit; tiempo=toc(inicio);
end




function X = reparar_angulos_71(X,limInferior,Sup)
% Recorta los limites y ordena cada vector para garantizar alfa1<alfa2<alfa3.
limInferior=limInferior(:)'; Sup=Sup(:)';
epsAng=1e-8;
lb=limInferior+epsAng; ub=Sup-epsAng;
X=min(max(X,lb),ub);
X=sort(X,2);

for i=1:size(X,1)
    for k=2:size(X,2)
        if X(i,k)<=X(i,k-1)
            X(i,k)=X(i,k-1)+epsAng;
        end
    end
    % Si la separacion empujo el ultimo angulo, desplaza toda la fila.
    if X(i,end)>ub(end)
        X(i,:)=X(i,:)-(X(i,end)-ub(end));
    end
    % Proteccion adicional cerca del limite inferior.
    if X(i,1)<lb(1)
        X(i,:)=X(i,:)+(lb(1)-X(i,1));
    end
end
end



function bandera = es_mejor_71(fNuevo,hNuevo,fViejo,hViejo)
% Reglas de factibilidad de Deb.
if hNuevo==0 && hViejo==0
    bandera=fNuevo<fViejo;
elseif hNuevo==0 && hViejo~=0
    bandera=true;
elseif hNuevo~=0 && hViejo==0
    bandera=false;
else
    bandera=hNuevo<hViejo;
end
end




function ind = mejor_indice_71(Fit,H)
ind=1;
for i=2:numel(Fit)
    if es_mejor_71(Fit(i),H(i),Fit(ind),H(ind)), ind=i; end
end
end




function valor = mejor_valor_71(Fit,H)
ind=mejor_indice_71(Fit,H);
valor=Fit(ind);
end



function [f,h]=evaluar_71(THDFUN,x)
% El objetivo integrado siempre devuelve f,h. No ocultar excepciones reales.
[f,h]=THDFUN(x);
end
