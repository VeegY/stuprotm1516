#include <mpi.h>
#include <stdlib.h> 
#include <stdio.h>
#include <string.h>
#include <iostream>
#include <iomanip>
#include <cmath>
#include "include/l2norm_test_help.hpp"
#include "include/roofline_help.hpp"
#include "include/timer.hpp"
using namespace std;

//------------------------------------------------------------------------------------------------/
//                                   APPLICATION SETTINGS
//------------------------------------------------------------------------------------------------/
//16384 - 65536 - 262144 - 1048576 - 4194304
#define dimension 1048576
#define iteration 10000
bool get_overall = false;

template<typename type>
float invoke_gpu_time(type *vector, type *result, int dim, int runs);

template<typename type>
void invoke_gpu_overall(type *vector, type *result, int dim);

template<typename type>
void allocation(type **data, size_t size);

template <typename type>
void cleanup(type *data);


int main(int argc, char* argv[])
{
   
    double *vector_host = new double[dimension];
    set_data(vector_host, dimension);

    Timer timer_overall;
    float elapsed_overall = 0.0;
//================================================================================================/
//									THE MAGIC HAPPENS HERE
//================================================================================================/
//------------------------------------------------------------------------------------------------/
//                                   Zeitmessung Overall
//------------------------------------------------------------------------------------------------/
    if (get_overall)
    {
        timer_overall.start();
        for (int r = 0; r < iteration; r++)
        {
            double *vector_dev = NULL;
            double *result = NULL;

            allocation(&vector_dev, dimension);
            allocation(&result, 1);

            copy_data(vector_host, vector_dev, dimension);

            //invoke_gpu_overall(vector_dev, result, dimension);

            cleanup(vector_dev);
            cleanup(result);
        }
        elapsed_overall = (timer_overall.stop()*1.0e3) / (float)iteration;
    }

//------------------------------------------------------------------------------------------------/
//                                   Zeitmessung Kernel
//------------------------------------------------------------------------------------------------/
    
    double *vector_dev = NULL;
    double *result = NULL;
    int size_result = ceil((double)dimension / 1024);
    printf("0\n");
    allocation(&vector_dev, dimension);
    allocation(&result, size_result);
    printf("1\n");
    copy_data(vector_host, vector_dev, dimension);
    printf("2\n");
    //=========================================//
    float elapsed_kernel = invoke_gpu_time(vector_dev, result, dimension, iteration);
    //>>>KERNEL<<<
    //=========================================//
    printf("3\n");
    
    //l2norm_check_result_(result, vector_host, dimension);
    cleanup(vector_dev);
    cleanup(result);
    printf("4\n");
//================================================================================================/
//                                         Evaluieren
//================================================================================================/

    double schalter = 0.0;
    //performance(dimension, elapsed_overall, elapsed_kernel, schalter, iteration);
    printf("done\n");
    delete[] vector_host;

    return 0;
}

