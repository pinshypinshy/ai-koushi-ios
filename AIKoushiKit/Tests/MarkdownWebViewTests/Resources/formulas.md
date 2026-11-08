# 数式の描画テスト用の教材

$\mathbf{u}=R\mathbf{x}+\mathbf{t}$

$(x,y)$

$(x,y,1)$

$s$

$(x,y,1)\sim(sx,sy,s)$

$w=0$

$(x,y,0)$

$\mathbf{p}'=M\mathbf{p}$

$\mathbf{p}=(x,y,1)^T$

$$
M_S=\begin{pmatrix} s_x & 0 & 0 \\ 0 & s_y & 0 \\ 0 & 0 & 1 \end{pmatrix},\quad M_R=\begin{pmatrix} \cos\theta & -\sin\theta & 0 \\ \sin\theta & \cos\theta & 0 \\ 0 & 0 & 1 \end{pmatrix},\quad M_T=\begin{pmatrix} 1 & 0 & t_x \\ 0 & 1 & t_y \\ 0 & 0 & 1 \end{pmatrix}
$$

$M_RM_T\neq M_TM_R$

$(x_c,y_c)$

$$
M_{RC}=M_T^{-1}M_RM_T=\begin{pmatrix} \cos\theta & -\sin\theta & x_c(1-\cos\theta)+y_c\sin\theta \\ \sin\theta & \cos\theta & -x_c\sin\theta+y_c(1-\cos\theta) \\ 0 & 0 & 1 \end{pmatrix}
$$

$C$

$L$

$\theta$

$L\tan(\theta/2)$

$\dfrac{3}{4}L\tan(\theta/2)$

$=12\tan30^\circ=12/\sqrt3=4\sqrt3$

$=3\sqrt3$

$y=0.299R+0.587G+0.114B$

$(X,Y,Z)$

$f$

$$
x=f\frac{X}{Z},\qquad y=f\frac{Y}{Z}\qquad(Z\neq0)
$$

$f$

$x:f=X:Z$

$f\gg\Delta Z$

$x=cX,\ y=cY$

$w_x$

$$
\theta=2\tan^{-1}\frac{w_x/2}{f}\quad\Longleftrightarrow\quad f=\frac{w_x/2}{\tan(\theta/2)}
$$

$(u,v)$

$(c_u,c_v)$

$$
u=f\frac{X}{Z}+c_u,\qquad v=f\frac{Y}{Z}+c_v
$$

$s(u,v,1)^T=K[I\,|\,0](X,Y,Z,1)^T$

$$
K=\begin{pmatrix} f & 0 & c_u \\ 0 & f & c_v \\ 0 & 0 & 1 \end{pmatrix}
$$

$s$

$s=Z$

$\mathbf{M}_w=(X_w,Y_w,Z_w)^T$

$\mathbf{M}=(X,Y,Z)^T$

$$
\mathbf{M}=R\mathbf{M}_w+\mathbf{t}\qquad\text{（同次座標では }\ \begin{pmatrix}\mathbf{M}\\1\end{pmatrix}=\begin{pmatrix} R & \mathbf{t} \\ \mathbf{0}^T & 1 \end{pmatrix}\begin{pmatrix}\mathbf{M}_w\\1\end{pmatrix}\text{）}
$$

$R$

$R^{-1}=R^T$

$\mathbf{t}$

$(R,\mathbf{t})$

$\mathbf{M}_w=R^T(\mathbf{M}-\mathbf{t})$

$$
s\begin{pmatrix} u \\ v \\ 1 \end{pmatrix}=P\begin{pmatrix} X_w \\ Y_w \\ Z_w \\ 1 \end{pmatrix},\qquad P=K\,[\,R\,|\,\mathbf{t}\,]\quad(3\times4)
$$

$C$

$f$

$(X_n,Y_n,Z_n)$

$(u_n,v_n)$

$s(u,v,1)^T=P(X,Y,Z,1)^T$

$s$

$$
P_{11}X_n+P_{12}Y_n+P_{13}Z_n+P_{14}-P_{31}X_nu_n-P_{32}Y_nu_n-P_{33}Z_nu_n-P_{34}u_n=0
$$

$v$

$P$

$n>11/2$

$B\mathbf{p}=\mathbf{q}$

$$
\mathbf{p}=(B^TB)^{-1}B^T\mathbf{q}\qquad(\text{}\ J(\mathbf{p})=\lVert B\mathbf{p}-\mathbf{q}\rVert^2\ \text{を最小化})
$$

$K$

$x_d=(1+\kappa_1r^2+\kappa_2r^4)x_u$

$y$

$r^2=x_u^2+y_u^2$

$\kappa_1<0$

$\kappa_1>0$

$K$

$n$

$[R\,|\,\mathbf{t}]$

$Z(u,v)$

$$
Z=d,\qquad X=\frac{(u-c_u)\,Z}{f},\qquad Y=\frac{(v-c_v)\,Z}{f}
$$

$\mathbf{M}_w=R^T(\mathbf{M}-\mathbf{t})$

$x=\pm1,y=\pm1,0\le z\le1$

$t\to\infty$

$m$

$n$

$m\times n$

$m+n$

$P$

$P$

$\mathbf{m}$

$K$

$\hat{\mathbf{x}}=K^{-1}\mathbf{m}$

$\mathbf{X}'=R\mathbf{X}+\mathbf{t}$

$R\hat{\mathbf{x}}$

$\hat{\mathbf{x}}'$

$\mathbf{t}$

$$
\hat{\mathbf{x}}'^{\,T}E\,\hat{\mathbf{x}}=0,\qquad E=[\mathbf{t}]_\times R
$$

$$
[\mathbf{t}]_\times=\begin{pmatrix} 0 & -t_Z & t_Y \\ t_Z & 0 & -t_X \\ -t_Y & t_X & 0 \end{pmatrix}
$$

$E$

$\mathbf{m}$

$A,A'$

$\hat{\mathbf{x}}=A^{-1}\mathbf{m}$

$$
\mathbf{m}'^{\,T}F\,\mathbf{m}=0,\qquad F=(A'^{-1})^{T}\,[\mathbf{t}]_\times R\,A^{-1}=(A'^{-1})^{T}E\,A^{-1}
$$

$\mathbf{m}$

$F\mathbf{m}$

$a x'+b y'+c=0$

$F$

$E$

$E$

$F$

$$
d=x-x'\quad(\text{視差})
$$

$B$

$f$

$$
\begin{pmatrix} X \\ Y \\ Z \end{pmatrix}=\frac{1}{d}\begin{pmatrix} xB \\ yB \\ fB \end{pmatrix}\qquad\Longrightarrow\qquad Z=\frac{fB}{d}
$$

$Z$

$d$

$d$

$$
\mathrm{SSD}(d)=\sum_{\text{window}}\bigl|I(u+d,v)-I'(u',v')\bigr|^2
$$

$\mathrm{ID}=1/Z=d/(fB_n)$

$\theta,\phi,L$

$Z(u,v)$

$(X,Y,Z)$

$(X,Y,Z)$

- $[R\,|\,\mathbf{t}]$

- $R,\mathbf{t}$

$$
\text{point-to-point：}\ \arg\min\sum_i\bigl\lVert \mathbf{p}_i^A-(R\mathbf{p}_i^B+\mathbf{t})\bigr\rVert^2
$$

$$
\text{point-to-plane：}\ \arg\min\sum_i\bigl\lVert \mathbf{n}_i^A\cdot\{\mathbf{p}_i^A-(R\mathbf{p}_i^B+\mathbf{t})\}\bigr\rVert^2
$$

$\mathbf{p}$

$r$

$\{\mathbf{p}_i\}_{i=1}^K$

$$
C=\frac{1}{K}\sum_{i=1}^{K}(\mathbf{p}_i-\bar{\mathbf{p}})(\mathbf{p}_i-\bar{\mathbf{p}})^T
$$

$C$

$\lambda_1>\lambda_2>\lambda_3$

$\lambda_3$

$\mathbf{e}_3$

$$
\text{curvature}=\frac{\lambda_3}{\lambda_1+\lambda_2+\lambda_3}
$$

$\lambda_3\approx0$

$\mathbf{v}$

$d$

$S(\mathbf{v})=0$

$\mathbf{p}$

$\mathbf{n}$

$L=\mathbf{n}\cdot(\mathbf{v}-\mathbf{p})$

$S=0$

$y=f(x)$

$g(x,y)=0$

$(x,y)=(x(t),y(t))$

$n$

$n-1$

$t=-1,0,1,2$

$B_i(t)$

$x=\sum_i x_iB_i(t),\ y=\sum_i y_iB_i(t)$

$B_i(t_i)=1,\ B_i(t_j)=0\,(i\neq j)$

$P_0,P_1,P_2,P_3$

$$
P(t)=\sum_{i=0}^{3}P_i\,B_i^3(t)\qquad(0\le t\le1)
$$

$$
B_0^3=(1-t)^3,\quad B_1^3=3t(1-t)^2,\quad B_2^3=3t^2(1-t),\quad B_3^3=t^3
$$

$P_0,P_3$

$P_1,P_2$

$$
P'(t)=-3(1-t)^2P_0+3(1-t)(1-3t)P_1+3t(2-3t)P_2+3t^2P_3
$$

$$
P'(0)=3(P_1-P_0),\qquad P'(1)=3(P_3-P_2)
$$

- $P_0$

- $P_0P_1$

- $P_3$

- $P_2P_3$

$k$

$$
P_i^{(k)}(t)=(1-t)\,P_i^{(k-1)}(t)+t\,P_{i+1}^{(k-1)}(t)
$$

$P_0^{(3)}(t)$

$t=0.5$

- $P'(t)$

- $t$

- $3(P_1-P_0)$

- $P(t^*)=$

- $t=0.5$

- $P(0.5)=\frac18(P_0+3P_1+3P_2+P_3)$

- $P(t_1)=P(t_2)\,(t_1\neq t_2)$

- $x(1-t)=-x(t)$

- $=0$

- $dy/dt=0$

$$
v-e+f=2\qquad(v:\text{頂点数},\ e:\text{辺数},\ f:\text{面数})
$$

$$
v-e+f-r=2(s-h)
$$

$r$

$s$

$h$

$\Delta v-\Delta e+\Delta f=0$

$\Delta e=\Delta v=1$

$\Delta f=\Delta e=1$

$\Delta(v-e+f)=0$

$\Delta v=1,\Delta e=3,\Delta f=+2$

$\Delta(v-e+f)=1-3+2=0$

- $D(r)=D_0\exp(-a r^2)$

- $D_0$

- $a$

- $r$

- $=$

- $z=h(x,y)$

$z_{n+1}=z_n^2+c$

$n$

$A$

$$
d=\frac{\log A}{\log n}
$$

$d=\log4/\log3\approx1.26$

$\log3/\log2\approx1.59$

$1\le d\le2$

$d$

$(x,y,z,1)$

$4\times4$

$+\infty$

$$
M_r(z\text{軸})=\begin{pmatrix} \cos\theta & -\sin\theta & 0 & 0 \\ \sin\theta & \cos\theta & 0 & 0 \\ 0 & 0 & 1 & 0 \\ 0 & 0 & 0 & 1 \end{pmatrix},\quad M_t=\begin{pmatrix} 1 & 0 & 0 & t_x \\ 0 & 1 & 0 & t_y \\ 0 & 0 & 1 & t_z \\ 0 & 0 & 0 & 1 \end{pmatrix}
$$

$$
M_s=\mathrm{diag}(s_x,s_y,s_z,1),\quad M_{\text{mirror(xy)}}=\mathrm{diag}(1,1,-1,1)
$$

$$
R_x(\theta)=\begin{pmatrix} 1 & 0 & 0 \\ 0 & \cos\theta & -\sin\theta \\ 0 & \sin\theta & \cos\theta \end{pmatrix},\ R_y(\theta)=\begin{pmatrix} \cos\theta & 0 & \sin\theta \\ 0 & 1 & 0 \\ -\sin\theta & 0 & \cos\theta \end{pmatrix},\ R_z(\theta)=\begin{pmatrix} \cos\theta & -\sin\theta & 0 \\ \sin\theta & \cos\theta & 0 \\ 0 & 0 & 1 \end{pmatrix}
$$

$(A,B,C)$

$(x_1,y_1,z_1)$

$V=\sqrt{B^2+C^2}$

$\theta$

$(1,1,1)$

$120^\circ$

$$
\begin{pmatrix} 0 & 0 & 1 \\ 1 & 0 & 0 \\ 0 & 1 & 0 \end{pmatrix}\ \text{（}(x,y,z)\mapsto(z,x,y)\text{）}
$$

$(A,B,C)$

$\theta$

$$
q=\Bigl(\cos\tfrac{\theta}{2}\,;\ A\sin\tfrac{\theta}{2},\ B\sin\tfrac{\theta}{2},\ C\sin\tfrac{\theta}{2}\Bigr)
$$

$\mathbf{p}=(x,y,z)$

$Q_P=(0;x,y,z)$

$$
Q_{P'}=q\,Q_P\,q^{*}\qquad(q^{*}\text{ は共役：ベクトル部の符号反転})
$$

$Q_{P'}=qQ_Pq^*$

$\mathbf{p}'=R\mathbf{p}$

$R$

$q=(w;x,y,z)$

$$
R=\begin{pmatrix} 1-2(y^2+z^2) & 2(xy-wz) & 2(xz+wy) \\ 2(xy+wz) & 1-2(x^2+z^2) & 2(yz-wx) \\ 2(xz-wy) & 2(yz+wx) & 1-2(x^2+y^2) \end{pmatrix}
$$

$Y$

$q=(\cos\tfrac\theta2;0,\sin\tfrac\theta2,0)$

$R_y(\theta)$

$\mathbf{n}$

$$
D_f=(P_E-P_i)\cdot\mathbf{n}\qquad(P_E:\text{視点})
$$

$D_f<0$

$P_i,P_j,P_k$

$\mathbf{n}=(P_i-P_j)\times(P_j-P_k)$

$z$

$Z_{\max}$

$z$

$Z(i,j)$

$z$

$n_xx+n_yy+n_zz+d=0$

$z=-(n_xx+n_yy+d)/n_z$

$x$

$$
\Delta z_x=-\frac{n_x}{n_z}
$$

$z$

$z$

$P=\hat{E}t+P_E$

$\lVert P-S\rVert=r$

$$
at^2+2bt+c=0,\quad a=\lVert\hat{E}\rVert^2=1,\ b=\hat{E}\cdot(P_E-S),\ c=\lVert P_E-S\rVert^2-r^2
$$

$D=b^2-ac\ge0$

$D<0$

$(P-P_1)\cdot\mathbf{n}=0$

$$
t=-\frac{(P_E-P_i)\cdot\mathbf{n}}{\hat{E}\cdot\mathbf{n}}\qquad(\hat{E}\cdot\mathbf{n}\neq0)
$$

$t>0$

$P$

- $+\infty$

- $q_x=M_{00}p_x+M_{10}p_y+M_{20}p_z+M_{30}$

- $M$

- $P$

$P'(t)$

$P(t^*)$

$=0$

$v-e+f=2$

$\Delta(v-e+f)=0$

$d=\log A/\log n$

$z$

$z$

$K$

$f$

$R,\mathbf{t}$

$P=K[R|t]$

$E=[\mathbf{t}]_\times R$

$F$

$[R|t]$
