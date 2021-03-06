
#ifdef USE_OMP
#include "omp.h"
#endif // USE_OMP

#include "ismrmrd/ismrmrd.h"
#include "complext.h"

#include <gtest/gtest.h>

#include "hoNDArray_utils.h"

#include "gtPlusIOAnalyze.h"

#include "GadgetronTimer.h"

#include "GtPLplot.h"

#ifdef max
#undef max
#endif // max

using namespace Gadgetron;
using namespace Gadgetron::gtPlus;
using testing::Types;

template <typename T> class gt_plplot_Test : public ::testing::Test 
{
protected:
    virtual void SetUp()
    {
        GDEBUG_STREAM("=============================================================================================");
        gt_ut_folder_ = std::string(::getenv("GADGETRON_UNITTEST_DIRECTORY"));
        GDEBUG_STREAM("=============================================================================================");
        GDEBUG_STREAM("Unit Test for GtPlus");
        gt_ut_data_folder_ = gt_ut_folder_ + "/data/";
        gt_ut_res_folder_ = gt_ut_folder_ + "/result/";
        GDEBUG_STREAM("gt_ut_data_folder_ is " << gt_ut_data_folder_);
        GDEBUG_STREAM("gt_ut_res_folder_ is " << gt_ut_res_folder_);

        timer_.set_timing_in_destruction(false);

#ifdef WIN32
    #ifdef USE_OMP
        /// lock the threads
        #pragma omp parallel default(shared)
        {
            int tid = omp_get_thread_num();
            // std::cout << tid << std::endl;
            DWORD_PTR mask = (1 << tid);
            SetThreadAffinityMask( GetCurrentThread(), mask );
        }
    #endif // USE_OMP
#endif // WIN32
    }

    std::string gt_ut_folder_;
    std::string gt_ut_data_folder_;
    std::string gt_ut_res_folder_;

    gtPlusIOAnalyze gt_io_;
    GadgetronTimer timer_;
};

typedef Types<float, double> realImplementations;

typedef Types< std::complex<float> > cpfloatImplementations;

typedef Types<std::complex<float>, std::complex<double>, float_complext, double_complext> cplxImplementations;
typedef Types<std::complex<float>, std::complex<double> > stdCplxImplementations;
typedef Types<float_complext, double_complext> cplxtImplementations;

TYPED_TEST_CASE(gt_plplot_Test, cpfloatImplementations);

TYPED_TEST(gt_plplot_Test, plplot_noise_covariance_test)
{
    typedef std::complex<float> T;

    gtPlusIOAnalyze gt_io;

    float v;

    std::string xlabel = "Channel";
    std::string ylabel = "Noise STD";
    std::string title = "Gadgetron SNR toolkit, Noise STD Plot";
    size_t xsize = 2048;
    size_t ysize = 2048;
    hoNDArray<float> plotIm;

    bool trueColor = true;

    hoNDArray< std::complex<float> > m;
    m.create(32, 32);
    Gadgetron::fill(m, std::complex<float>(1.0, 0) );

    std::vector<std::string> coilStrings(32);

    for (size_t n=0; n < m.get_size(0); n++)
    {
        std::ostringstream ostr;
        ostr << "Channel" << "_" << n;

        coilStrings[n] = ostr.str();
    }

    Gadgetron::plotNoiseStandardDeviation(m, coilStrings, xlabel, ylabel, title, xsize, ysize, trueColor, plotIm);

    gt_io.exportArray(plotIm, this->gt_ut_res_folder_ + "plplot_trueColor_NoiseSTD");
}
