use std::path::Path;

#[flutter_rust_bridge::frb]
pub fn document_to_pdf(path: String) -> Result<Vec<u8>, String> {
    let ext = Path::new(&path)
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();

    match ext.as_str() {
        "docx" | "docm" | "dotx" | "dotm" => {
            zavora_docx::Document::open(&path)
                .map_err(|error| format!("Failed to load document: {error}"))?
                .to_pdf()
                .map_err(|error| format!("Failed to render document: {error}"))
        }
        "doc" | "odt" | "rtf" => {
            let text = office_oxide::extract_text(&path)
                .map_err(|error| format!("Failed to load document: {error}"))?;
            let mut document = zavora_docx::Document::new();
            for paragraph in text.split('\n') {
                document.add_paragraph(paragraph);
            }
            document
                .to_pdf()
                .map_err(|error| format!("Failed to render document: {error}"))
        }
        _ => Err(format!("Unsupported document type: {ext}")),
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_docx_without_office() {
        let path = std::env::temp_dir().join(format!(
            "defile_docx_test_{}.docx",
            std::process::id()
        ));
        let mut document = zavora_docx::Document::new();
        document.add_paragraph("Hello preview");
        document.save(&path).unwrap();

        let pdf = document_to_pdf(path.to_string_lossy().into_owned()).unwrap();
        assert!(pdf.starts_with(b"%PDF"));

        let _ = std::fs::remove_file(path);
    }
}


