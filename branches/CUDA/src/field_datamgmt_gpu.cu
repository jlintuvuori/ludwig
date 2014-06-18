/*****************************************************************************
 *
 * field_datamgmt_gpu.cu
 *  
 * Field data management for GPU adaptation of Ludwig
 * Alan Gray 
 *
 *****************************************************************************/


#include <stdio.h>

#include "utilities_gpu.h"
#include "field_datamgmt_gpu.h"
#include "field_datamgmt_internal_gpu.h"
#include "util.h"
#include "model.h"
#include "colloids.h"

/* host memory address pointers for temporary staging of data */
double * phi_site_temp;
double * colloid_force_tmp;
double * grad_phi_site_temp;
double * delsq_phi_site_temp;
double * ftmp;
double * force_temp;
double * velocity_temp;


extern double * f_;


/* pointers to data resident on accelerator */
extern int * N_d;

extern char * mask_;

/* accelerator memory address pointers for required data structures */
double * f_d;
double * ftmp_d;
double * phi_site_d;
double * phi_site_temp_d;
double * phi_site_full_d;
double * grad_phi_site_full_d;
float * grad_phi_float_d;
double * h_site_d;
double * stress_site_d;
double * grad_phi_site_d;
double * delsq_phi_site_d;
double * le_index_real_to_buffer_d;
double * colloid_force_d;
double * force_d;
double * velocity_d;

int * le_index_real_to_buffer_temp;

/* data size variables */
static int nhalo;
static int nsites;
static int ndata;
static int ndist;
static int nop;
static  int N[3];
static  int Nall[3];
static int nlexbuf;

static double field_tmp[100];



void init_field_gpu(){

  int ic;

  calculate_field_data_sizes();
  allocate_field_memory_on_gpu();
  

  /* get le_index_to_real_buffer values */
/*le_index_real_to_buffer holds -1 then +1 translation values */
  for (ic=0; ic<Nall[X]; ic++)
    {

      le_index_real_to_buffer_temp[ic]=
	le_index_real_to_buffer(ic,-1);

      le_index_real_to_buffer_temp[Nall[X]+ic]=
le_index_real_to_buffer(ic,+1);

    }

  cudaMemcpy(le_index_real_to_buffer_d, le_index_real_to_buffer_temp, 
	     nlexbuf*sizeof(int),cudaMemcpyHostToDevice);


}


void finalise_field_gpu()
{
  free_field_memory_on_gpu();

}

/* calculate sizes of data - needed for memory copies to accelerator */
static void calculate_field_data_sizes()
{
  coords_nlocal(N);  
  nhalo = coords_nhalo();  
  ndist = distribution_ndist();
  nop = phi_nop();

  Nall[X]=N[X]+2*nhalo;
  Nall[Y]=N[Y]+2*nhalo;
  Nall[Z]=N[Z]+2*nhalo;

  nsites = Nall[X]*Nall[Y]*Nall[Z];

  ndata = nsites * ndist * NVEL;





  //nlexbuf = le_get_nxbuffer();
/*for holding le buffer index translation */
/* -1 then +1 values */
  nlexbuf = 2*Nall[X]; 



}





/* Allocate memory on accelerator */
static void allocate_field_memory_on_gpu()
{

  cudaHostAlloc( (void **)&ftmp, ndata*sizeof(double), 
		 cudaHostAllocDefault);

  cudaHostAlloc( (void **)&colloid_force_tmp, nsites*6*3*sizeof(double), 
		 cudaHostAllocDefault);


  /* temp arrays for staging data on  host */
  phi_site_temp = (double *) malloc(nsites*nop*sizeof(double));
  grad_phi_site_temp = (double *) malloc(nsites*nop*3*sizeof(double));
  delsq_phi_site_temp = (double *) malloc(nsites*nop*sizeof(double));
  le_index_real_to_buffer_temp = (int *) malloc(nlexbuf*sizeof(int));
  force_temp = (double *) malloc(nsites*3*sizeof(double));
  velocity_temp = (double *) malloc(nsites*3*sizeof(double));



  /* arrays on accelerator */
  cudaMalloc((void **) &f_d, ndata*sizeof(double));
  cudaMalloc((void **) &ftmp_d, ndata*sizeof(double));

  

  cudaMalloc((void **) &phi_site_d, nsites*nop*sizeof(double));
  cudaMalloc((void **) &phi_site_temp_d, nsites*nop*sizeof(double));
  cudaMalloc((void **) &phi_site_full_d, nsites*9*sizeof(double));
  cudaMalloc((void **) &grad_phi_site_full_d, nsites*27*sizeof(double));
  cudaMalloc((void **) &grad_phi_float_d, nsites*27*sizeof(float)); 
  cudaMalloc((void **) &h_site_d, nsites*9*sizeof(double));
  cudaMalloc((void **) &stress_site_d, nsites*9*sizeof(double));
  cudaMalloc((void **) &delsq_phi_site_d, nsites*nop*sizeof(double));
  cudaMalloc((void **) &grad_phi_site_d, nsites*3*nop*sizeof(double));
  cudaMalloc((void **) &le_index_real_to_buffer_d, nlexbuf*sizeof(int));
 cudaMalloc((void **) &colloid_force_d, nsites*6*3*sizeof(double));
  cudaMalloc((void **) &force_d, nsites*3*sizeof(double));
   cudaMalloc((void **) &velocity_d, nsites*3*sizeof(double));

     checkCUDAError("allocate_phi_memory_on_gpu");

}


/* Free memory on accelerator */
static void free_field_memory_on_gpu()
{

  /* free temp memory on host */
  free(phi_site_temp);
  free(grad_phi_site_temp);
  free(delsq_phi_site_temp);
  free(le_index_real_to_buffer_temp);
  free(force_temp);
  free(velocity_temp);


  cudaFreeHost(ftmp);
  cudaFreeHost(colloid_force_tmp);

  cudaFree(f_d);
  cudaFree(ftmp_d);
  cudaFree(phi_site_d);
  cudaFree(phi_site_temp_d);
  cudaFree(phi_site_full_d);
  cudaFree(grad_phi_site_full_d);
  cudaFree(grad_phi_float_d);
  cudaFree(h_site_d);
  cudaFree(stress_site_d);
  cudaFree(delsq_phi_site_d);
  cudaFree(grad_phi_site_d);
  cudaFree(le_index_real_to_buffer_d);
  cudaFree(colloid_force_d);
  cudaFree(force_d);
  cudaFree(velocity_d);


}

void put_all_fields_on_gpu()
{
  put_f_on_gpu();
  put_phi_on_gpu();
  put_grad_phi_on_gpu();
  put_force_on_gpu();
  put_delsq_phi_on_gpu();
  put_velocity_on_gpu();
  put_site_map_on_gpu();
  //put_fluxes_on_gpu();
}


void get_all_fields_from_gpu()
{
  get_f_from_gpu();
  get_phi_from_gpu();
  get_grad_phi_from_gpu();
  get_force_from_gpu();
  get_delsq_phi_from_gpu();
  get_velocity_from_gpu();
}

/* copy f_ from host to accelerator */
void put_f_on_gpu()
{

  /* copy data from CPU to accelerator */
  cudaMemcpy(f_d, f_, ndata*sizeof(double), cudaMemcpyHostToDevice);

}


/* copy f_ from accelerator back to host */
void get_f_from_gpu()
{

  /* copy data from accelerator to host */
  cudaMemcpy(f_, f_d, ndata*sizeof(double), cudaMemcpyDeviceToHost);

}

void switch_f_and_ftmp_on_gpu()
{

  double *tmpptr=ftmp_d;
  ftmp_d=f_d;
  f_d=tmpptr;

}

/* copy f to ftmp on accelerator */
void copy_f_to_ftmp_on_gpu()
{
  /* copy data on accelerator */
  cudaMemcpy(ftmp_d, f_d, ndata*sizeof(double), cudaMemcpyDeviceToDevice);


  //checkCUDAError("cp_f_to_ftmp_on_gpu");

}


void get_phi_site(int index, double *field){

  int nop=phi_nop();
  int iop;
  for (iop=0; iop<nop; iop++)
    {
      
      field[iop]=phi_op_get_phi_site(index,iop);
    }
  

}



void set_phi_site(int index, double *field){

  int nop=phi_nop();
  int iop;
  for (iop=0; iop<nop; iop++)
    {
      phi_op_set_phi_site(index,iop,field[iop]);      

    }
  

}


/* copy phi from host to accelerator */
void put_phi_on_gpu()
{

  int index, iop;
	      
  for (index=0;index<nsites;index++){

    get_phi_site(index,field_tmp);

    for (iop=0; iop<nop; iop++) 
      phi_site_temp[iop*nsites+index]=field_tmp[iop]; 

  }


  /* copy data from CPU to accelerator */
  cudaMemcpy(phi_site_d, phi_site_temp, nsites*nop*sizeof(double), \
	     cudaMemcpyHostToDevice);

  checkCUDAError("put_phi_on_gpu");

}


/* copy phi from accelerator to host */
void get_phi_from_gpu()
{

  int index, iop;
	      

  /* copy data from accelerator to host */
  cudaMemcpy(phi_site_temp, phi_site_d, nsites*nop*sizeof(double),	\
         cudaMemcpyDeviceToHost);

  for (index=0;index<nsites;index++){

    for (iop=0; iop<nop; iop++)
      {
	field_tmp[iop]=phi_site_temp[iop*nsites+index];
	set_phi_site(index,field_tmp);
      }
  }

  checkCUDAError("get_phi_from_gpu");

}


/* copy grad phi from host to accelerator */
void put_grad_phi_on_gpu()
{

  int index, i, iop;
  double grad_phi[3];
	      

  for (index=0;index<nsites;index++){
    
    for (iop=0; iop<nop; iop++)
      {
	phi_gradients_grad_n(index, iop, grad_phi);
	
	for (i=0;i<3;i++)
	    grad_phi_site_temp[i*nsites*nop+iop*nsites+index]=grad_phi[i];
      }
  }

  /* copy data from CPU to accelerator */
  cudaMemcpy(grad_phi_site_d, grad_phi_site_temp, 
	     nsites*nop*3*sizeof(double),	
	     cudaMemcpyHostToDevice);
  
  
  checkCUDAError("put_grad_phi_on_gpu");
  
}

/* copy grad phi from accelerator to host*/
void get_grad_phi_from_gpu()
{
  
  int index, i, iop;
  double grad_phi[3];
  
  
  /* copy data from accelerator to CPU */
  cudaMemcpy(grad_phi_site_temp, grad_phi_site_d, nsites*nop*3*sizeof(double), \
	     cudaMemcpyDeviceToHost);
  
  
  for (index=0;index<nsites;index++){
    
    for (iop=0; iop<nop; iop++)
      {
	
	for (i=0;i<3;i++)
	  grad_phi[i]=grad_phi_site_temp[i*nsites*nop+iop*nsites+index];
	
	
	phi_gradients_set_grad_n(index, iop, grad_phi);
	
      }
  } 
  
  checkCUDAError("get_grad_phi_from_gpu");
  
}

/* copy phi from host to accelerator */
void put_delsq_phi_on_gpu()
{

  int index, iop;

  for (index=0;index<nsites;index++){
 
    for (iop=0; iop<nop; iop++)
      delsq_phi_site_temp[iop*nsites+index] = phi_gradients_delsq_n(index,iop);
    
  }
  
  /* copy data from CPU to accelerator */
  cudaMemcpy(delsq_phi_site_d, delsq_phi_site_temp, nsites*nop*sizeof(double), \
	     cudaMemcpyHostToDevice);

  checkCUDAError("put_delsq_phi_on_gpu");

}

/* copy delsq phi from accelerator to host*/
void get_delsq_phi_from_gpu()
{

  int index, iop;

  /* copy data from CPU to accelerator */
  cudaMemcpy(delsq_phi_site_temp, delsq_phi_site_d, nsites*nop*sizeof(double), \
	     cudaMemcpyDeviceToHost);

  for (index=0;index<nsites;index++){

	      for (iop=0; iop<nop; iop++)
		phi_gradients_set_delsq_n(index,iop,
				   delsq_phi_site_temp[iop*nsites+index]);
	      	      
  }

  checkCUDAError("get_delsq_phi_from_gpu");

}



__global__ void expand_phi_on_gpu_d(double* phi_site_d,double* phi_site_full_d)
{
  
  int index = blockIdx.x*blockDim.x+threadIdx.x;
  
  /* Avoid going beyond problem domain */
  if (index < Nall_cd[X]*Nall_cd[Y]*Nall_cd[Z])
    {
      
      
      /* calculate index from CUDA thread index */
      
      phi_site_full_d[3*X*nsites_cd+X*nsites_cd+index]
	= phi_site_d[nsites_cd*XX+index];
      phi_site_full_d[3*X*nsites_cd+Y*nsites_cd+index]
	= phi_site_d[nsites_cd*XY+index];
      phi_site_full_d[3*X*nsites_cd+Z*nsites_cd+index]
	= phi_site_d[nsites_cd*XZ+index];
      phi_site_full_d[3*Y*nsites_cd+X*nsites_cd+index]
	=  phi_site_full_d[3*X*nsites_cd+Y*nsites_cd+index];
      phi_site_full_d[3*Y*nsites_cd+Y*nsites_cd+index]
	= phi_site_d[nsites_cd*YY+index];
      phi_site_full_d[3*Y*nsites_cd+Z*nsites_cd+index]
	= phi_site_d[nsites_cd*YZ+index];
      phi_site_full_d[3*Z*nsites_cd+X*nsites_cd+index]
	= phi_site_full_d[3*X*nsites_cd+Z*nsites_cd+index];
      phi_site_full_d[3*Z*nsites_cd+Y*nsites_cd+index]
	= phi_site_full_d[3*Y*nsites_cd+Z*nsites_cd+index];
      phi_site_full_d[3*Z*nsites_cd+Z*nsites_cd+index]
	= 0.0 -  phi_site_full_d[3*X*nsites_cd+X*nsites_cd+index]
	-  phi_site_full_d[3*Y*nsites_cd+Y*nsites_cd+index];


    }

}
void expand_phi_on_gpu()
{
  int N[3],nhalo,Nall[3];
  nhalo = coords_nhalo();
  coords_nlocal(N);
  Nall[X]=N[X]+2*nhalo;
  Nall[Y]=N[Y]+2*nhalo;
  Nall[Z]=N[Z]+2*nhalo;
  int nsites=Nall[X]*Nall[Y]*Nall[Z];
  
  cudaMemcpyToSymbol(N_cd, N, 3*sizeof(int), 0, cudaMemcpyHostToDevice);
  cudaMemcpyToSymbol(Nall_cd, Nall, 3*sizeof(int), 0, cudaMemcpyHostToDevice);
  cudaMemcpyToSymbol(nhalo_cd, &nhalo, sizeof(int), 0, cudaMemcpyHostToDevice);
  cudaMemcpyToSymbol(nsites_cd, &nsites, sizeof(int), 0, cudaMemcpyHostToDevice); 
  
  int nblocks=(Nall[X]*Nall[Y]*Nall[Z]+DEFAULT_TPB-1)/DEFAULT_TPB;
  
  expand_phi_on_gpu_d<<<nblocks,DEFAULT_TPB>>>
    (phi_site_d,phi_site_full_d);
  cudaThreadSynchronize();

checkCUDAError("expand_phi_on_gpu");
 
}

__global__ void expand_grad_phi_on_gpu_d(double* grad_phi_site_d,double* grad_phi_site_full_d, float *grad_phi_float_d)
{
  
  
  int index = blockIdx.x*blockDim.x+threadIdx.x;
  
  /* Avoid going beyond problem domain */
  if (index < Nall_cd[X]*Nall_cd[Y]*Nall_cd[Z])
    {
      
      
      /* /\* calculate index from CUDA thread index *\/ */
      int ia;
      for(ia=0;ia<3;ia++){
      	grad_phi_site_full_d[ia*nsites_cd*9+3*X*nsites_cd+X*nsites_cd+index]
      	  = grad_phi_site_d[ia*nsites_cd*5+nsites_cd*XX+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*X*nsites_cd+Y*nsites_cd+index]
      	  = grad_phi_site_d[ia*nsites_cd*5+nsites_cd*XY+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*X*nsites_cd+Z*nsites_cd+index]
      	  = grad_phi_site_d[ia*nsites_cd*5+nsites_cd*XZ+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*Y*nsites_cd+X*nsites_cd+index]
      	  =  grad_phi_site_full_d[ia*nsites_cd*9+3*X*nsites_cd+Y*nsites_cd+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*Y*nsites_cd+Y*nsites_cd+index]
      	  = grad_phi_site_d[ia*nsites_cd*5+nsites_cd*YY+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*Y*nsites_cd+Z*nsites_cd+index]
      	  = grad_phi_site_d[ia*nsites_cd*5+nsites_cd*YZ+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*Z*nsites_cd+X*nsites_cd+index]
      	  = grad_phi_site_full_d[ia*nsites_cd*9+3*X*nsites_cd+Z*nsites_cd+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*Z*nsites_cd+Y*nsites_cd+index]
      	  = grad_phi_site_full_d[ia*nsites_cd*9+3*Y*nsites_cd+Z*nsites_cd+index];
      	grad_phi_site_full_d[ia*nsites_cd*9+3*Z*nsites_cd+Z*nsites_cd+index]
      	  = 0.0 -  grad_phi_site_full_d[ia*nsites_cd*9+3*X*nsites_cd+X*nsites_cd+index]
      	  -  grad_phi_site_full_d[ia*nsites_cd*9+3*Y*nsites_cd+Y*nsites_cd+index];
      }


    } 

}
void expand_grad_phi_on_gpu()
{
  int N[3],nhalo,Nall[3];
  nhalo = coords_nhalo();
  coords_nlocal(N);
  Nall[X]=N[X]+2*nhalo;
  Nall[Y]=N[Y]+2*nhalo;
  Nall[Z]=N[Z]+2*nhalo;
  int nsites=Nall[X]*Nall[Y]*Nall[Z];
  
  cudaMemcpyToSymbol(N_cd, N, 3*sizeof(int), 0, cudaMemcpyHostToDevice);
  cudaMemcpyToSymbol(Nall_cd, Nall, 3*sizeof(int), 0, cudaMemcpyHostToDevice);
  cudaMemcpyToSymbol(nhalo_cd, &nhalo, sizeof(int), 0, cudaMemcpyHostToDevice);
  cudaMemcpyToSymbol(nsites_cd, &nsites, sizeof(int), 0, cudaMemcpyHostToDevice); 
  
  int nblocks=(Nall[X]*Nall[Y]*Nall[Z]+DEFAULT_TPB-1)/DEFAULT_TPB;
  
    expand_grad_phi_on_gpu_d<<<nblocks,DEFAULT_TPB>>>
      (grad_phi_site_d,grad_phi_site_full_d,grad_phi_float_d);

    //texture<float,1,cudaReadModeElementType> texreference;

checkCUDAError("expand_grad_phi_on_gpu");



 
}



void zero_force_on_gpu()
{

  int zero=0;
  cudaMemset(force_d,zero,nsites*3*sizeof(double));
  checkCUDAError("zero_force_on_gpu");
}


/* copy force from host to accelerator */
void put_force_on_gpu()
{

  int index, i;
  double force[3];
	      

  for (index=0;index<nsites;index++){
    
    hydrodynamics_get_force_local(index,force);
    
    for (i=0;i<3;i++)
	force_temp[i*nsites+index]=force[i];
    
  }

  /* copy data from CPU to accelerator */
  cudaMemcpy(force_d, force_temp, nsites*3*sizeof(double), \
	     cudaMemcpyHostToDevice);

  checkCUDAError("put_force_on_gpu");

}

/* copy force from accelerator to host */
void get_force_from_gpu()
{

  int index, i;
  double force[3];
	      
  /* copy data from accelerator to CPU */
  cudaMemcpy(force_temp, force_d, nsites*3*sizeof(double), \
	     cudaMemcpyDeviceToHost);

  
  for (index=0;index<nsites;index++){

    for (i=0;i<3;i++)
      force[i]=force_temp[i*nsites+index];
    
    hydrodynamics_set_force_local(index,force);
    
  }



  checkCUDAError("get_force_from_gpu");

}



void get_velocity_from_gpu()
{
  int index,i;
  double velocity[3];

  cudaMemcpy(velocity_temp, velocity_d, nsites*3*sizeof(double),
	    cudaMemcpyDeviceToHost);

  for (index=0;index<nsites;index++){

    for (i=0;i<3;i++)
      velocity[i]=velocity_temp[nsites*i+index];

    hydrodynamics_set_velocity(index,velocity);
  }

  checkCUDAError("get_velocity_from_gpu");

}



void put_velocity_on_gpu()
{
  int index,i;
  double velocity[3];


  for (index=0;index<nsites;index++){

    hydrodynamics_get_velocity(index,velocity);

    for (i=0;i<3;i++)
      velocity_temp[i*nsites+index]=velocity[i];

  }

  cudaMemcpy(velocity_d, velocity_temp, nsites*3*sizeof(double),
	    cudaMemcpyHostToDevice);

  checkCUDAError("put_velocity_on_gpu");


}


void phi_halo_gpu(){
#ifdef KEVIN_GPU
  extern int q_halo_gpu(double * data);
  q_halo_gpu(phi_site_d);
#else
  halo_gpu(1,nop,0,phi_site_d);
#endif
}

extern double * velocity_d;
void velocity_halo_gpu(){
#ifdef KEVIN_GPU
  extern int u_halo_gpu(double * u_d);
  u_halo_gpu(velocity_d);
#else
  halo_gpu(1,3,0,velocity_d);
#endif
}

void distribution_halo_gpu(){
#ifdef KEVIN_GPU
  extern int dist_halo_gpu(double *);
  dist_halo_gpu(f_d);
#else
  halo_gpu(NVEL,ndist,1,f_d);
#endif

}


/* copy part of velocity_ from host to accelerator, using mask structure */
void put_velocity_partial_on_gpu(int include_neighbours)
{

  int nfields1=1;
  int nfields2=3;
  double *data_d=velocity_d;
  void (* access_function)(const int, double *);

  access_function= hydrodynamics_get_velocity;
  
  put_field_partial_on_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

}

/* copy part of velocity_ from host to accelerator, using mask structure */
void get_velocity_partial_from_gpu(int include_neighbours)
{

  int nfields1=1;
  int nfields2=3;
  double *data_d=velocity_d;
  void (* access_function)(const int, double *);

  access_function= hydrodynamics_set_velocity;
  
  get_field_partial_from_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

}

/* copy part of velocity_ from host to accelerator, using mask structure */
void put_phi_partial_on_gpu(int include_neighbours)
{

  int nfields1=1;
  int nfields2=phi_nop();
  double *data_d=phi_site_d;
  void (* access_function)(const int, double *);

  access_function=get_phi_site;
  
  put_field_partial_on_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

}

/* copy part of velocity_ from host to accelerator, using mask structure */
void get_phi_partial_from_gpu(int include_neighbours)
{

  int nfields1=1;
  int nfields2=phi_nop();
  double *data_d=phi_site_d;
  void (* access_function)(const int, double *);

  access_function=set_phi_site;
  
  get_field_partial_from_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

}


void get_f_site(int index, double *field){

  int i;
  for (i=0; i<(NVEL*ndist); i++)
    {
      field[i]=f_[nsites*i+index];    
    }
  

}



void set_f_site(int index, double *field){

  int i;
  for (i=0; i<(NVEL*ndist); i++)
    {
      f_[nsites*i+index]=field[i];
    }
  
}


void put_f_partial_on_gpu(int include_neighbours)
{

  int nfields1=NVEL;
  int nfields2=ndist;
  double *data_d=f_d;
  void (* access_function)(const int, double *);

  access_function=get_f_site;
  
  put_field_partial_on_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

}

/* copy part of f from host to accelerator, using mask structure */
void get_f_partial_from_gpu(int include_neighbours)
{

  int nfields1=NVEL;
  int nfields2=ndist;
  double *data_d=f_d;
  void (* access_function)(const int, double *);

  access_function=set_f_site;
  
  get_field_partial_from_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

}

void set_colloid_force_site(int index, double *field){

  int i;
  for (i=0; i<(3*6); i++)
      colloid_force_tmp[i*nsites+index]=field[i];
}


void update_colloid_force_from_gpu()
{
  int index,index1,i, ic,jc,kc;
  colloid_t * p_c;


  memset(mask_,0,nsites*sizeof(char));

  for (ic=1; ic<Nall[X]-1; ic++){
    for (jc=1; jc<Nall[Y]-1; jc++){
      for (kc=1; kc<Nall[Z]-1; kc++){
	
  	index = get_linear_index(ic, jc, kc, Nall);

  	if (colloid_at_site_index(index)){
	  
  	  index1=get_linear_index(ic+1, jc, kc, Nall);
  	  if (!colloid_at_site_index(index1))
	    mask_[index1]=1;

  	  index1=get_linear_index(ic-1, jc, kc, Nall);
  	  if (!colloid_at_site_index(index1))
	    mask_[index1]=1;

  	  index1=get_linear_index(ic, jc+1, kc, Nall);
  	  if (!colloid_at_site_index(index1))
	    mask_[index1]=1;

  	  index1=get_linear_index(ic, jc-1, kc, Nall);
  	  if (!colloid_at_site_index(index1))
	    mask_[index1]=1;

  	  index1=get_linear_index(ic, jc, kc+1, Nall);
  	  if (!colloid_at_site_index(index1))
	    mask_[index1]=1;

  	  index1=get_linear_index(ic, jc, kc-1, Nall);
  	  if (!colloid_at_site_index(index1))
	    mask_[index1]=1;

  	}
	  
      }
      }
      }
  


  int include_neighbours=0;
  int nfields1=6;
  int nfields2=3;
  double *data_d=colloid_force_d;
  void (* access_function)(const int, double *);

  access_function=set_colloid_force_site;
  
    get_field_partial_from_gpu(nfields1,nfields2,include_neighbours,data_d,access_function);

  for (ic=1; ic<Nall[X]-1; ic++)
    for (jc=1; jc<Nall[Y]-1; jc++)
      for (kc=1; kc<Nall[Z]-1; kc++){

	  
	  index = get_linear_index(ic, jc, kc, Nall); 	      




	  if (!mask_[index]) continue;

	  p_c = colloid_at_site_index(index);
	  
	  if (p_c) continue;
	  
	  
	  index1 = get_linear_index(ic+1, jc, kc, Nall);
	  p_c = colloid_at_site_index(index1);
	  if (p_c) {
	    for (i=0;i<3;i++){
	      p_c->force[i] += colloid_force_tmp[0*nsites*3+nsites*i+index];
	    }
	  }
	  
	  
	  index1 = get_linear_index(ic-1, jc, kc, Nall);
	  p_c = colloid_at_site_index(index1);
	  if (p_c) {
	    for (i=0;i<3;i++){
	      p_c->force[i] += colloid_force_tmp[1*nsites*3+nsites*i+index];
	    }
	  }
	  
	  
	  index1 = get_linear_index(ic, jc+1, kc, Nall);
	  p_c = colloid_at_site_index(index1);
	  if (p_c) {
	    for (i=0;i<3;i++){
	      p_c->force[i] += colloid_force_tmp[2*nsites*3+nsites*i+index];
	    }
	  }
	  
	  
	  index1 = get_linear_index(ic, jc-1, kc, Nall);
	  p_c = colloid_at_site_index(index1);
	  if (p_c) {
	    for (i=0;i<3;i++){
	      p_c->force[i] += colloid_force_tmp[3*nsites*3+nsites*i+index];
	    }
	  }
	  
	  
	  index1 = get_linear_index(ic, jc, kc+1, Nall);
	  p_c = colloid_at_site_index(index1);
	  if (p_c) {
	    for (i=0;i<3;i++){
	      p_c->force[i] += colloid_force_tmp[4*nsites*3+nsites*i+index];
	    }
	  }
	  
	  
	  index1 = get_linear_index(ic, jc, kc-1, Nall);
	  p_c = colloid_at_site_index(index1);
	  if (p_c) {
	    for (i=0;i<3;i++){
	      p_c->force[i] += colloid_force_tmp[5*nsites*3+nsites*i+index];
	    }
	  }
	  
	}

      checkCUDAError("update_colloid_force_from_gpu");

}



double sum_f_from_gpu(){

  get_f_from_gpu();

  int i;
  double sum=0;
  for (i=0;i<ndata;i++){
    sum+=f_[i];
  }

  return sum;
    
    


}


double sum_phi_from_gpu(){

  get_phi_from_gpu();

  int i;
  double sum=0;
  for (i=0;i<nop*nsites;i++){
    sum+=phi_site_temp[i];
  }

  return sum;
    

}

double sum_grad_phi_from_gpu(){

  get_grad_phi_from_gpu();

  int i;
  double sum=0;
  for (i=0;i<nop*nsites*3;i++){
    sum+=grad_phi_site_temp[i];
  }

  return sum;
    

}

double sum_delsq_phi_from_gpu(){

  get_delsq_phi_from_gpu();

  int i;
  double sum=0;
  for (i=0;i<nop*nsites;i++){
    sum+=delsq_phi_site_temp[i];
  }

  return sum;
    

}

double sum_force_from_gpu(){

  get_force_from_gpu();

  int i;
  double sum=0;
  for (i=0;i<nsites*3;i++){
    sum+=force_temp[i];
  }

  return sum;
    

}

double sum_velocity_from_gpu(){

  get_velocity_from_gpu();

  int i;
  double sum=0;
  for (i=0;i<nsites*3;i++){
    sum+=velocity_temp[i];
  }

  return sum;
    

}

