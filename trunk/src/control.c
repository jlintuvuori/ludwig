/*****************************************************************************
 *
 *  control.c
 *
 *  Model control and time stepping.
 *
 *  Kevin Stratford (kevin@epcc.ed.ac.uk)
 *
 *****************************************************************************/

#include "pe.h"
#include "runtime.h"
#include "control.h"

static int t_start   = 0;
static int t_steps   = 0;
static int t_current = 0;

static int freq_statistics = 100;
static int freq_measure    = 1000;
static int freq_config     = 10000;

/*****************************************************************************
 *
 *  init_control
 *
 *  Look at the user input and set time step information.
 *
 *****************************************************************************/

void init_control() {

  int n;

  n = RUN_get_int_parameter("N_cycles", &t_steps);
  n = RUN_get_int_parameter("t_start", &t_start);
  n = RUN_get_int_parameter("freq_statistics", &freq_statistics);
  n = RUN_get_int_parameter("freq_measure", &freq_measure);
  n = RUN_get_int_parameter("freq_config", &freq_config);

  t_current = t_start;

  if (freq_statistics < 1) freq_statistics = t_start + t_steps + 1;
  if (freq_measure    < 1) freq_measure    = t_start + t_steps + 1;
  if (freq_config     < 1) freq_config     = t_start + t_steps + 1;

  return;
}

/*****************************************************************************
 *
 *  get_step
 *  next step
 *
 *****************************************************************************/

int get_step() {
  return t_current;
}

int next_step() {
  ++t_current;
  return (t_start + t_steps - t_current + 1);
}


/*****************************************************************************
 *
 *  is_statistics_step
 *
 *****************************************************************************/

int is_statistics_step() {
  return ((t_current % freq_statistics) == 0);
}

int is_measurement_step() {
  return ((t_current % freq_measure) == 0);
}

int is_config_step() {
  return ((t_current % freq_config) == 0);
}
