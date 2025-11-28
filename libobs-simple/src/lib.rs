#![cfg_attr(doc, feature(doc_cfg))]
//! A simplified interface for recording and streaming with libobs

pub mod output;
pub mod sources;

pub use libobs_wrapper as wrapper;
