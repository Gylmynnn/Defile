use lopdf::Document;
use std::process::Command;

pub fn get_pdf_page_count(path: String) -> Result<i32, String> {
    let document = Document::load(&path).map_err(|e| format!("Failed to load PDF: {}", e))?;
    Ok(document.get_pages().len() as i32)
}

pub fn render_pdf_page(path: String, page_index: i32, width: i32) -> Result<Vec<u8>, String> {
    // ponytail: use pdftoppm (poppler-utils), replace with pure Rust when available
    let output = Command::new("pdftoppm")
        .arg("-png")
        .arg("-singlefile")
        .arg("-f")
        .arg((page_index + 1).to_string())
        .arg("-l")
        .arg((page_index + 1).to_string())
        .arg("-scale-to")
        .arg(width.to_string())
        .arg(&path)
        .output()
        .map_err(|e| format!("Failed to execute pdftoppm: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "pdftoppm failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(output.stdout)
}

pub struct PdfPageInfo {
    pub width: f64,
    pub height: f64,
}

pub fn get_pdf_page_info(path: String, page_index: i32) -> Result<PdfPageInfo, String> {
    let document = Document::load(&path).map_err(|e| format!("Failed to load PDF: {}", e))?;
    let pages = document.get_pages();
    
    let page_id = pages
        .get(&((page_index + 1) as u32))
        .ok_or("Page not found")?;
    
    let page = document
        .get_dictionary(*page_id)
        .map_err(|e| format!("Failed to get page: {}", e))?;
    
    if let Ok(media_box) = page.get(b"MediaBox") {
        if let Ok(arr) = media_box.as_array() {
            if arr.len() >= 4 {
                let width = match &arr[2] {
                    lopdf::Object::Real(v) => *v as f64,
                    lopdf::Object::Integer(v) => *v as f64,
                    _ => 612.0,
                };
                let height = match &arr[3] {
                    lopdf::Object::Real(v) => *v as f64,
                    lopdf::Object::Integer(v) => *v as f64,
                    _ => 792.0,
                };
                return Ok(PdfPageInfo { width, height });
            }
        }
    }
    
    Ok(PdfPageInfo { width: 612.0, height: 792.0 })
}
