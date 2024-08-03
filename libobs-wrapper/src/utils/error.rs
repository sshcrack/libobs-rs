use std::fmt::Display;
use crate::enums::ObsResetVideoStatus;


/// Error type for OBS function calls.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ObsError {
    /// The `obs_startup` function failed on libobs.
    Failure,
    /// Failed to lock mutex describing whether there is a
    /// thread using libobs or not. Report to crate maintainer.
    MutexFailure,
    /// Some or no thread is already using libobs. This is a bug!
    ThreadFailure,
    /// Unable to reset video.
    ResetVideoFailure(ObsResetVideoStatus),
    /// Unable to reset video because the program attempted to
    /// change the graphics module. This is a bug!
    ResetVideoFailureGraphicsModule,
    /// The function returned a null pointer, often indicating
    /// an error with creating the object of the requested
    /// pointer.
    NullPointer,
    OutputAlreadyActive,
    OutputStartFailure(Option<String>),
    OutputStopFailure(Option<String>),
}

impl Display for ObsError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "OBS Error: ")?;

        match self {
            ObsError::Failure => write!(f, "`obs-startup` function failed on libobs"),
            ObsError::MutexFailure => write!(f, "Failed to lock mutex describing whether there is a thread using libobs or not. Report to crate maintainer."),
            ObsError::ThreadFailure => write!(f, "Some or no thread is already using libobs. This is a bug!"),
            ObsError::ResetVideoFailure(status) => write!(f, "Could not reset obs video. Status: {:?}", status),
            ObsError::ResetVideoFailureGraphicsModule => write!(f, "Unable to reset video because the program attempted to change the graphics module. This is a bug!"),
            ObsError::NullPointer => write!(f, "The function returned a null pointer, often indicating an error with creating the object of the requested pointer."),
            ObsError::OutputAlreadyActive => write!(f, "Output is already active."),
            ObsError::OutputStartFailure(s) => write!(f, "Output failed to start. Error is {:?}", s),
            ObsError::OutputStopFailure(s) => write!(f, "Output failed to stop. Error is {:?}", s),
        }
    }
}

impl std::error::Error for ObsError {}