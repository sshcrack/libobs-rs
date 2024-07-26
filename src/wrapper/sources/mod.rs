use super::{obstypes::ObsSource, ObsData, ObsError, ObsOutput, ObsString, SourceInfo};

#[cfg(target_family = "windows")]
mod windows;

use proc_macro::TokenStream;
use quote::quote;
use syn::parse_macro_input;
#[cfg(target_family = "windows")]
pub use windows::*;

#[allow(private_bounds)]
pub(super) trait ObsSourceBuilderPrivate {
    fn take_settings(&mut self) -> Option<ObsData>;
    fn take_hotkeys(&mut self) -> Option<ObsData>;
}

pub trait ObsSourceBuilderId {
    /// Returns the ID of the source.
    fn get_id() -> ObsString;
}

//TODO Use generics to make the build function return a trait rather than a struct
/// Trait for building OBS sources.
pub trait ObsSourceBuilder: ObsSourceBuilderPrivate + ObsSourceBuilderId {
    fn new(name: impl Into<ObsString>) -> Self;

    /// Returns the name of the source.
    fn get_name(&self) -> ObsString;

    /// Adds the obs source to the output on the given channel
    fn add<'a>(
        mut self,
        output: &'a mut ObsOutput,
        channel: u32,
    ) -> Result<&'a mut ObsSource, ObsError>
    where
        Self: Sized,
    {
        let settings = self.take_settings();
        let hotkeys = self.take_hotkeys();

        let source = SourceInfo::new(Self::get_id(), self.get_name(), settings, hotkeys);
        output.source(source, channel)
    }

    fn get_settings(&self) -> &Option<ObsData>;
    fn get_settings_mut(&mut self) -> &mut Option<ObsData>;

    fn get_hotkeys(&self) -> &Option<ObsData>;
    fn get_hotkeys_mut(&mut self) -> &mut Option<ObsData>;

    fn get_or_create_settings(&mut self) -> &mut ObsData {
        self.get_settings_mut().get_or_insert_with(ObsData::new)
    }
}


/// Use this attribute on a struct to create a obs source builder.
#[proc_macro_attribute]
pub(super) fn obs_source_builder(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let input = parse_macro_input!(item as ItemStruct);
    let name = input.ident;
    let generics = input.generics;


    let expanded = quote! {
        struct #name #generics {
            #fields,
            settings: Option<ObsData>,
            hotkeys: Option<ObsData>,
            name: ObsString
        }

        impl ObsSourceBuilder for #name {
            fn new(name: impl Into<ObsString>) -> Self {
                Self {
                    settings: None,
                    hotkeys: None,
                    name: name.into(),
                }
            }

            fn get_settings(&self) -> &Option<ObsData> {
                &self.settings
            }

            fn get_settings_mut(&mut self) -> &mut Option<ObsData> {
                &mut self.settings
            }

            fn get_hotkeys(&self) -> &Option<ObsData> {
                &self.hotkeys
            }

            fn get_hotkeys_mut(&mut self) -> &mut Option<ObsData> {
                &mut self.hotkeys
            }

            fn get_name(&self) -> ObsString {
                self.name.clone()
            }
        }

        impl ObsSourceBuilderPrivate for #name {
            fn take_settings(&mut self) -> Option<ObsData> {
                self.settings.take()
            }

            fn take_hotkeys(&mut self) -> Option<ObsData> {
                self.hotkeys.take()
            }
        }
    };

    TokenStream::from(expanded)
}