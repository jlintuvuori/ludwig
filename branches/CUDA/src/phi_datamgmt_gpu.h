/*****************************************************************************
 * 
 * phi_datamgmt_gpu.h
 * 
 * Phi data management utilities for GPU adaptation of Ludwig
 * Alan Gray
 *
 *****************************************************************************/

#ifndef PHIUTILITIES_GPU_H
#define PHIUTILITIES_GPU_H

#include "common_gpu.h"

/* declarations for required external (host) routines */
extern "C" double phi_get_phi_site(const int);
extern "C" double phi_op_get_phi_site(const int index, const int nop);
extern "C" void phi_set_phi_site(const int, const double);
extern "C" void phi_op_set_phi_site(const int, const int, const double);
extern "C" void   phi_gradients_grad_n(const int index, const int iop, double grad[3]);
extern "C" void   phi_gradients_set_grad_n(const int index, const int iop, double grad[3]);
extern "C" double phi_gradients_delsq_n(const int index, const int iop);
extern "C" void phi_gradients_set_delsq_n(const int index, const int iop, const double delsq);
extern "C" void TIMER_start(const int);
extern "C" void TIMER_stop(const int);
extern "C" void halo_gpu(int nfields1, int nfields2, int packfield1, double * data_d);

/* expose routines in this module to outside routines */
extern "C" void put_phi_on_gpu();
extern "C" void put_phi_on_gpu();
extern "C" void put_grad_phi_on_gpu();
extern "C" void put_delsq_phi_on_gpu();
extern "C" void get_phi_from_gpu();
extern "C" void get_grad_phi_from_gpu();
extern "C" void get_delsq_phi_from_gpu();
extern "C" void get_phi_edges_from_gpu(void);
extern "C" void put_phi_halos_on_gpu(void);
extern "C" void phi_halo_gpu(void);
extern "C" void velocity_halo_gpu(void);
extern "C" void expand_phi_on_gpu();

/* forward declarations of host routines internal to this module */
static void calculate_phi_data_sizes(void);
static void allocate_phi_memory_on_gpu(void);
static void free_phi_memory_on_gpu(void);
void init_phi_gpu();
void finalise_phi_gpu();


#endif

