use env_logger::Env;
use libobs_simple::output::simple::ObsContextSimpleExt;
use libobs_wrapper::{
    context::ObsContext,
    data::output::ObsOutputRef,
    utils::{ObsPath, StartupInfo},
};

/// The string returned is the name of the obs output
#[allow(dead_code)]
pub fn initialize_obs<T: Into<ObsPath> + Send + Sync>(rec_file: T) -> (ObsContext, ObsOutputRef) {
    let _ = env_logger::Builder::from_env(Env::default().default_filter_or("debug"))
        .is_test(true)
        .try_init();

    #[allow(unused_mut)]
    let mut context = ObsContext::new(StartupInfo::default()).unwrap();

    let rec_file: ObsPath = rec_file.into();
    let output = context
        .simple_output_builder("test_obs_output", rec_file)
        .build()
        .unwrap();

    (context, output)
}
