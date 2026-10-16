import numpy as np,pandas as pd,json
from pathlib import Path
from scipy.stats import friedmanchisquare,rankdata
from scipy.io import loadmat
p=Path(__file__).resolve().parent/'principal_250V';T=pd.read_csv(p/'resultados_corridas.csv');E=pd.read_csv(p/'mejoras_evaluacion_exacta.csv');C=pd.read_csv(p/'convergencia_por_corrida.csv');S=pd.read_csv(p/'resumen_comparativo.csv')
assert len(T)==120 and T.groupby('Metodo').size().eq(30).all()
assert T.EvaluacionesTotales.eq(201000).all()
a=T[['Alpha1_deg','Alpha2_deg','Alpha3_deg']].values;n=np.arange(1,50,2)
v=4*83.33/(n*np.pi)*np.cos(np.deg2rad(a[:,:,None]*n)).sum(1)
thd=100*np.linalg.norm(v[:,1:],axis=1)/abs(v[:,0]);err=abs(250-v[:,0]);j=thd+10*err
assert np.max(abs(T.FuncionObjetivo_J-j))<1e-8
assert np.max(abs(T.THD_pct-thd))<1e-8
hits=[]
for r in T.itertuples():
 ev=E[(E.Metodo==r.Metodo)&(E.Semilla==r.Semilla)]
 hit=ev[(ev.J<=r.LimiteJ)&(ev.ErrorV_V<=.1)]
 assert bool(len(hit))==bool(r.AlcanzoObjetivo)
 if len(hit):assert hit.iloc[0].Evaluacion==r.EvaluacionesHastaObjetivo and abs(hit.iloc[0].TiempoInstrumentado_s-r.TiempoHastaObjetivo_s)<1e-10
 co=C[(C.Metodo==r.Metodo)&(C.Semilla==r.Semilla)]
 assert len(co)==201
 for ee,jj in zip(co.Evaluaciones,co.Mejor_J):
  assert abs(ev.loc[ev.Evaluacion<=ee,'J'].iloc[-1]-jj)<1e-8
for field,q,met in [('FuncionObjetivo_J',1e-9,'J'),('THD_pct',1e-9,'THD_pct'),('ErrorV_V',1e-9,'ErrorV_V'),('Tiempo_s',1e-6,'Tiempo_s')]:
 X=T.pivot(index='Semilla',columns='Metodo',values=field).values
 stat=friedmanchisquare(*np.round(X/q).T)
 O=pd.read_csv(p/'estadistica_Friedman.csv').set_index('Metrica').loc[met]
 assert abs(stat.statistic-O.Chi2_Friedman)<1e-9
F=pd.read_csv(p/'resumen_espectros.csv');delta=F.THD_pct.max()-F.THD_pct.min()
report={'rows':len(T),'events':len(E),'history_rows':len(C),'max_J_error':float(np.max(abs(T.FuncionObjetivo_J-j))),'max_THD_error':float(np.max(abs(T.THD_pct-thd))), 'delta_thd_pp':float(delta),'delta_thd_relative_percent':float(100*delta/F.THD_pct.min()),'equiv_harmonic_rms_V':float(250/np.sqrt(2)*delta/100),'afta_runtime_reduction_vs_de_pct':float(100*(1-S.set_index('Metodo').loc['AFTA','Tiempo_medio_s']/S.set_index('Metodo').loc['DE','Tiempo_medio_s']))}
for m,g in T.groupby('Metodo'):
 report[m]={'time_instrumented_mean':float(g.TiempoInstrumentado_s.mean()),'time_to_target_min':float(g.TiempoHastaObjetivo_s.min()),'time_to_target_max':float(g.TiempoHastaObjetivo_s.max()),'eval_to_target_min':float(g.EvaluacionesHastaObjetivo.min()),'eval_to_target_max':float(g.EvaluacionesHastaObjetivo.max()),'maxTHD':float(g.THD_pct.max())}
print(json.dumps(report,indent=2));(p.parent/'verificacion_numerica.json').write_text(json.dumps(report,indent=2))
