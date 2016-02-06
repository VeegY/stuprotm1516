#include <iostream>
#include <iomanip>
#include <stdio.h>
#include <string.h>
#include <cuda.h>
#include <cuda_runtime.h>
#include <cmath>

//KERNEL
template<typename type>
__global__ void  gpu_ax(type* data, type* fvec, type* result, int* indices, int max_row_length, int dim_local)
{

    int idx = threadIdx.x+blockDim.x*blockIdx.x;
    if(idx<dim_local)
    {
      int col;
      type svalue = 0, value;
      for(int i = 0;i < max_row_length; i++)
      {
        value = data[i*dim_local+idx];
        col = indices[i*dim_local+idx];
        svalue += value*fvec[col];
      }
      result[idx]=svalue;
    }
}


//CALCULATING MEMORY BANDWITH
template<typename type>
void bandwith(int max_row_length, int dim_local, float time)
{
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop,0);

    //===Immer selbstständig updaten wenn sich der Kernel ändert===//           
    int bRead = 0, bWrite = 0;
    bRead += max_row_length*dim_local*sizeof(type); //data-Array
    bRead += max_row_length*dim_local*sizeof(int);  //indices-Array
    bRead += max_row_length*dim_local*sizeof(type); //fvec-Array
    bWrite += dim_local*sizeof(type);               //result-Array
    
}
template void bandwith<int>(int dim_local, int max_row_length, float time);
template void bandwith<float>(int dim_local, int max_row_length, float time);
template void bandwith<double>(int dim_local, int max_row_length, float time);


//PROPERTIES OF TEGRA K1
void print_p()
{

    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop,0);
    
    printf("==============================\nDevice name: %s\n------------------------------\n", prop.name);
    printf("Memory Clock Rate (KHz): %d\n",prop.memoryClockRate);
    printf("Memory Bus Width (bits): %d\n",prop.memoryBusWidth);
    printf("Peak Memory Bandwidth (GB/s): %f\n==============================\n",2.0*prop.memoryClockRate*(prop.memoryBusWidth/8)/1.0e6);
    //printf("Max Threads Per Block: %i\n", prop.maxThreadsPerBlock);
    //printf("Max Grid Size: %ix%ix%i\n", prop.maxGridSize[0],prop.maxGridSize[1],prop.maxGridSize[2]);

}

//ALLOCATE MEMORY FUNCTION FOR UNIFIED MEMORY
template<typename Scalar>
void alloc_unified(Scalar **data, Scalar **fvec, Scalar **result, int **indices, int max_row_length, int dim_local,int dim_fvec)
{
    cudaMallocManaged((void **)data, sizeof(Scalar)*dim_local*max_row_length);
    cudaMallocManaged((void **)fvec, sizeof(Scalar)*dim_fvec);
    cudaMallocManaged((void **)result, sizeof(Scalar)*dim_local);
    cudaMallocManaged((void **)indices, sizeof(int)*dim_local*max_row_length);
}
template void alloc_unified<int>(int **data, int **fvec, int **result, int **indices, int max_row_length, int dim_local, int dim_fvec);
template void alloc_unified<float>(float **data, float **fvec, float **result, int **indices, int max_row_length, int dim_local, int dim_fvec);
template void alloc_unified<double>(double **data, double **fvec, double **result, int **indices, int max_row_length, int dim_local, int dim_fvec);


//ALLOCATE MEMORY FUNCTION FOR UNIFIED MEMORY for DistEllpack
template<typename Scalar>
void alloc_unifiedD(Scalar **data, int **indices, int max_row_length, int dim_local)
{
    cudaMallocManaged((void **)data, sizeof(Scalar)*dim_local*max_row_length);
    cudaMallocManaged((void **)indices, sizeof(int)*dim_local*max_row_length);
}
template void alloc_unifiedD<int>(int **data, int **indices, int max_row_length, int dim_local);
template void alloc_unifiedD<float>(float **data, int **indices, int max_row_length, int dim_local);
template void alloc_unifiedD<double>(double **data, int **indices, int max_row_length, int dim_local);

// ALLOCATE MEMORY FUNCTION FOR UNIFIED MEMORY FOR SLICEDVECTOR
template<typename Scalar>
void alloc_unifiedV(Scalar **fvec, int dim_fvec)
{
    cudaMallocManaged((void **)fvec, sizeof(Scalar)*dim_fvec);
}
template void alloc_unifiedV<int>(int **fvec, int dim_fvec);
template void alloc_unifiedV<float>(float **fvec, int dim_fvec);
template void alloc_unifiedV<double>(double **fvec, int dim_fvec);


//ALLOCATE MEMORY FUNCTION FOR ZERO COPY 
template<typename Scalar>
void alloc_zero(Scalar **data, Scalar **fvec, Scalar **result, int ** indices, int max_row_length, int dim_local, int dim_fvec)
{
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop,0);

    if(prop.canMapHostMemory)
    {
      cudaSetDeviceFlags(cudaDeviceMapHost);

      cudaHostAlloc((void **)data, sizeof(Scalar)*max_row_length*dim_local, cudaHostAllocMapped);
      cudaHostAlloc((void **)fvec, sizeof(Scalar)*dim_fvec, cudaHostAllocMapped);
      cudaHostAlloc((void **)result, sizeof(Scalar)*dim_local, cudaHostAllocMapped);
      cudaHostAlloc((void **)indices, sizeof(int)*max_row_length*dim_local, cudaHostAllocMapped);
    }
}
template void alloc_zero<int>(int **data, int **fvec, int **result, int **indices, int max_row_length, int dim_local, int dim_fvec);
template void alloc_zero<float>(float **data, float **fvec, float **result, int **indices, int max_row_length, int dim_local, int dim_fvec);
template void alloc_zero<double>(double **data, double **fvec, double **result, int **indices, int max_row_length, int dim_local, int dim_fvec);


//KERNEL CALL WITH UNIFIED MEMORY (NEED TO CALL ALLOC_UNIFIED BEFORE)
template<typename Scalar>
float mult_vec_unified(Scalar *data, Scalar *fvec, Scalar *result, int *indices, int max_row_length, int dim_local, int dim_fvec, int runs)
{
    Timer timer;
    int num_blocks = ceil((double)dim_local/1024);
    int num_threads = ceil(((double)dim_local/num_blocks)/32)*32;
    timer.start();
    for (int i=0;i<runs;++i)
    {
        gpu_ax<<<num_blocks,num_threads>>>(data,fvec,result,indices,max_row_length, dim_local);
    }
    cudaDeviceSynchronize();
    float ellapsedTime = timer.stop();
    
    return (ellapsedTime/50);

}
template void mult_vec_unified<int>(int* data, int* fvec, int* result, int* indices, int max_row_length, int dim_local,int dim_fvec);
template void mult_vec_unified<float>(float* data, float* fvec, float* result, int* indices, int max_row_length, int dim_local, int dim_fvec);
template void mult_vec_unified<double>(double* data, double* fvec, double* restult, int* indices, int max_row_length, int dim_local, int dim_fvec);


//KERNE CALL WITH ZERO COPY (NEED TO CALL ALLOC_ZERO BEFORE)
template<typename Scalar>
float mult_vec_zero(Scalar *data, Scalar *fvec, Scalar *result, int *indices, int max_row_length, int dim_local, int dim_fvec, int runs)
{
    Timer timer;
    Scalar *d_data, *d_fvec, *d_result;
    int *d_indices;

    cudaHostGetDevicePointer((void **)&d_data,(void *)data, 0);
    cudaHostGetDevicePointer((void **)&d_fvec, (void *)fvec, 0);
    cudaHostGetDevicePointer((void **)&d_result, (void *)result, 0);
    cudaHostGetDevicePointer((void **)&d_indices, (void *)indices, 0);

    int num_blocks = ceil((double)dim_local/1024);
    int num_threads = ceil(((double)dim_local/num_blocks)/32)*32;
    timer.start();
    for (int i=0;i<runs;++i)
    {
        gpu_ax<<<num_blocks,num_threads>>>(d_data, d_fvec, d_result, d_indices, max_row_length, dim_local);
    }
    cudaDeviceSynchronize();
    float ellapsedTime = timer.stop();
    
    return (ellapsedTime/50);
}
template void mult_vec_zero<int>(int* data, int* fvec, int* result, int* indices, int max_row_length, int dim_local, int  dim_fvec);
template void mult_vec_zero<float>(float* data, float* fvec, float* result, int* indices, int max_row_length, int dim_local, int dim_fvec);
template void mult_vec_zero<double>(double* data, double* fvec, double* restult, int* indices, int max_row_length, int dim_local, int dim_fvec);

template <typename Scalar>
void cleanup(Scalar *data, Scalar *fvec, Scalar *result, int *indices)
{
    cudaFreeHost(data);
    cudaFreeHost(fvec);
    cudaFreeHost(result);
    cudaFreeHost(indices);
}
template void cleanup<int>(int *data, int *fvec, int *result, int *indices);
template void cleanup<float>(float *data, float *fvec, float *result, int *indices);
template void cleanup<double>(double *data, double *fvec, double *result, int *indices);


template <typename Scalar>
void cleanupgpu(Scalar *data)
{   
    cudaFreeHost(data);
}
template void cleanupgpu<int>(int *data);
template void cleanupgpu<float>(float *data);
template void cleanupgpu<double>(double *data);
