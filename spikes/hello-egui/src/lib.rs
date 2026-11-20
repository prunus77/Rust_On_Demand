//! Phase 0 spike: smallest pure-Rust Android app with a UI.
//! A label, a button and a tap counter. Every tap is also written to logcat
//! under the tag "ipser", so the harness can check behaviour from logs alone.

use eframe::egui;

#[derive(Default)]
pub struct HelloApp {
    taps: u32,
    amount: String,
}

impl eframe::App for HelloApp {
    // eframe 0.37 API: the app gets a root `Ui` (older versions used `update(ctx, ..)`).
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ui, |ui| {
            ui.add_space(80.0);
            ui.vertical_centered(|ui| {
                ui.heading("Hello from Rust");
                ui.add_space(24.0);
                let button = egui::Button::new(egui::RichText::new("Tap me").size(32.0))
                    .min_size(egui::vec2(260.0, 120.0));
                if ui.add(button).clicked() {
                    self.taps += 1;
                    log::info!("IPSER_TAP count={}", self.taps);
                }
                ui.add_space(24.0);
                ui.label(egui::RichText::new(format!("Taps: {}", self.taps)).size(28.0));
                ui.add_space(24.0);
                // Text entry probe: a bill splitter needs numbers typed in.
                let edit = ui.add(
                    egui::TextEdit::singleline(&mut self.amount)
                        .hint_text("Amount")
                        .font(egui::FontId::proportional(28.0))
                        .desired_width(260.0),
                );
                if edit.changed() {
                    log::info!("IPSER_TEXT value={}", self.amount);
                }
            });
        });
    }
}

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
fn android_main(app: winit::platform::android::activity::AndroidApp) {
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Info)
            .with_tag("ipser"),
    );
    log::info!("IPSER_START hello-egui");

    let options = eframe::NativeOptions {
        android_app: Some(app),
        ..Default::default()
    };
    if let Err(e) = eframe::run_native(
        "Ipser Hello",
        options,
        Box::new(|_cc| Ok(Box::new(HelloApp::default()))),
    ) {
        log::error!("IPSER_FATAL {e}");
    }
}
