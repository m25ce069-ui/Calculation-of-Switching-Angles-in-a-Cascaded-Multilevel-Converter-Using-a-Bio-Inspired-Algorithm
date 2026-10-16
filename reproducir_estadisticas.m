function destino = reproducir_estadisticas()
% Recompute published inference from original saved runs, without optimization.
% Statistical helper functions below are copied unchanged from executed source.
raiz=fileparts(mfilename('fullpath'));
A=load(fullfile(raiz,'principal_250V','estudio.mat'),'estudio');
O=estadistica_chb(A.estudio);
destino=fullfile(raiz,['estadistica_reproducida_' datestr(now,'yyyymmdd_HHMMSS')]);
assert(~exist(destino,'dir'),'Output already exists; retry in a new second.');
mkdir(destino);
writetable(O.omnibus,fullfile(destino,'estadistica_Friedman.csv'));
writetable(O.pares,fullfile(destino,'estadistica_pares_Wilcoxon_Holm.csv'));
fprintf('Statistical results from original stored runs: %s\n',destino);
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

