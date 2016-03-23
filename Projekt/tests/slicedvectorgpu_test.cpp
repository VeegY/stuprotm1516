#include "../src/include/slicedvectorgpu.hpp"
#include "../src/include/vtkwriter.hpp"
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <limits>
/*
*test fuer slicedvectorgpu
*KEIN unit-test
*
*/
int slicedvectorgputest()
{
    srand (static_cast <unsigned> (time(0)));
	const size_t N=100000;
	Icarus::SlicedVectorGpu<double> vec1(N), vec2(N), vec4(N);
	Icarus::SlicedVectorGpu<double> vec6(N), vec7(N), vec8(N);
	size_t dimloc = vec1.get_dim_local();
	if (vec1.get_dim!=N){
        LOG_ERROR("get_dim failed");
	}
	double constdouble (static_cast <double> (rand()) / static_cast <double> (RAND_MAX));
	vec4.fill_const(constdouble);
	for (size_t i(0); i<dimloc; i++)
    {
        double r = static_cast <double> (rand()) / static_cast <double> (RAND_MAX);
        int sign=2*(rand()%2)-1;
        vec1[i]=r;
        vec6[i]=sign*r;
    }
    Icarus::SlicedVectorGpu<double> vec3(vec1); //test copy constructor
	vec2=vec1;
	size_t dimloc = vec1.get_dim_local();

	for (size_t i(0); i<dimloc; i++)
    {
        if (vec2[i]!=vec1[i])
        {
             LOG_ERROR("copy-constructor failed");
        }
        if (vec3[i]!=vec1[i])
        {
             LOG_ERROR("assignment operator failed");
        }
        if (vec4[i]!=constdouble)
        {
             LOG_ERROR("fill_const failed");
        }
    }

    //check artihmetic operations
    double randdouble= static_cast <double> (rand()) / static_cast <double> (RAND_MAX);
    double maxnorm(0), l2norm2(0);
    vec7=vec6;
    vec8=vec6;
    vec7.scal(randdouble);
    vec8.axpy(randdouble, vec7);
    for (size_t i(0); i<dimloc; i++)
    {
        l2norm2+=vec6[i]*vec6[i];
        if (std::abs(vec6[i]) > maxnorm )
        {
            maxnorm=std::abs(vec6[i]);
        }
        if (vec7[i]!=randdouble*vec6[i])
        {
             LOG_ERROR("scal failed ; value: ",vec7[i], "  reference value: ", randdouble*vec6[i]);
        }
        if (vec8[i]!=vec6[i]+randdouble*vec7[i])
        {
             LOG_ERROR("axpy failed; value: ",vec8[i], "  reference value: ", randdouble*vec6[i]+vec7[i]);
        }
    }
    /*
    double checktol = std::numeric_limits<double>::epsilon();
    double maxnorm_glob, l2norm2_glob;
    MPI_SCALL(MPI_Allreduce(&maxnorm, &maxnorm_glob, 1, ScalarTraits<double>::mpi_type, MPI_SUM, _my_comm));
    MPI_SCALL(MPI_Allreduce(&l2norm2, &l2norm2_glob, 1, ScalarTraits<double>::mpi_type, MPI_SUM, _my_comm));
    if (maxnorm!=vec6.maxnorm())
    {
        LOG_ERROR("maxnorm failed; value: ",vec6.maxnorm(), "  reference value: ", maxnorm);
    }
    if (std::abs(l2norm2-vec6.l2norm2())>=checktol*100*std::abs(l2norm2+vec6.l2norm2()))
    {
        LOG_ERROR("L2norm2 failed; value: ",vec6.l2norm2(), "  reference value: ", l2norm2, "  difference: ",l2norm2-vec6.l2norm2());
    }
    double l2norm=std::sqrt(l2norm2_glob);
    if (std::abs(l2norm-vec6.l2norm())>=checktol*100*std::abs(l2norm+vec6.l2norm()))
    {
        LOG_ERROR("L2norm failed; value: ",vec6.l2norm(), "  reference value: ", l2norm, "  difference: ",l2norm-vec6.l2norm());
    }
    */
    return 0;
}

int main()
{
    int myrank;
    MPI_SCALL(MPI_Comm_rank(MPI_COMM_WORLD, &myrank));
    if (myrank == 0)
    {
        return slicedvectorgputest();
    }
    return 0;
}
