from pathlib import Path
import numpy as np,pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=Path(__file__).resolve().parent/'principal_250V';out=p.parent/'figuras_articulo';out.mkdir(exist_ok=True)
T=pd.read_csv(p/'resultados_corridas.csv');names=['DE','TLBO','GWO','AFTA'];col=['#0072BD','#D95319','#40994D','#7E2F8E']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'axes.titlesize':12,'axes.labelsize':12,'legend.fontsize':10,'pdf.fonttype':42})
f,axes=plt.subplots(2,2,figsize=(7.1,4.9),sharex=True,sharey=True)
t=np.linspace(0,2*np.pi,8001)
for i,(m,ax) in enumerate(zip(names,axes.flat)):
 A=T[T.Metodo==m];r=A.loc[A.FuncionObjetivo_J.idxmin()];a=np.deg2rad(r[['Alpha1_deg','Alpha2_deg','Alpha3_deg']].values.astype(float));q=np.mod(t,np.pi);q=np.minimum(q,np.pi-q)
 vv=83.33*(q[:,None]>=a).sum(1)*np.where(t<np.pi,1,-1)
 ax.plot(t,vv,color=col[i],lw=1.5,label='Ideal stepped voltage');ax.plot(t,r.V1_V*np.sin(t),'k--',lw=.9,label='Fundamental')
 ax.set_title(m);ax.set_xticks([0,np.pi,2*np.pi],['0',r'$\pi$',r'$2\pi$']);ax.set_yticks([-250,0,250]);ax.grid(alpha=.2)
for ax in axes[:,0]:ax.set_ylabel('Voltage (V)')
for ax in axes[1,:]:ax.set_xlabel('Electrical angle (rad)')
f.legend(*axes[0,0].get_legend_handles_labels(),loc='lower center',ncol=2,bbox_to_anchor=(.5,.005),frameon=False)
f.tight_layout(rect=[0,.07,1,1]);f.savefig(out/'fig17.png',dpi=600);plt.close(f)
f,axs=plt.subplots(2,1,figsize=(7.1,5.8))
for ax,key,last,label in [(axs[0],'EvaluacionesHastaObjetivo',201000,'Objective-function evaluations'),(axs[1],'TiempoHastaObjetivo_s',T.TiempoInstrumentado_s.max(),'Instrumented elapsed time (s)')]:
 for i,m in enumerate(names):
  A=T[T.Metodo==m];v=np.sort(A.loc[A.AlcanzoObjetivo.astype(bool),key].values)
  ax.step(np.r_[0,v,last],100*np.r_[0,np.arange(1,len(v)+1)/30,len(v)/30],where='post',color=col[i],lw=1.7,label=m)
 ax.set(xlabel=label,ylabel='Runs reaching target (%)',ylim=(-2,105));ax.grid(alpha=.2)
axs[0].legend(ncol=4,loc='lower right',frameon=False);axs[0].set_title('(a) Evaluation effort');axs[1].set_title('(b) Elapsed time')
f.tight_layout();f.savefig(out/'fig18.png',dpi=600);plt.close(f)
