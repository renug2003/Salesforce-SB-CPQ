# Static Resources Required

## html2pdf.js — Required for PDF Generation

The `ddPdfGenerator` LWC uses the `html2pdf.js` library to convert the proposal
HTML to a downloadable PDF without leaving Salesforce.

### Setup Steps

**Option A — Download and upload manually:**

1. Download html2pdf.js bundle:
   ```
   https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js
   ```

2. In Salesforce Setup → Static Resources → New:
   - Name: `html2pdf`
   - File: upload the `.js` file
   - Cache Control: Public

3. Deploy the static resource:
   ```bash
   sf project deploy start --metadata StaticResource:html2pdf --target-org dd-cpq-dev
   ```

**Option B — Create via CLI (if you have the file locally):**
```bash
# After downloading html2pdf.bundle.min.js to your project root:
sf static-resource create --name html2pdf --type text/javascript
# Then copy the JS content into force-app/main/default/staticresources/html2pdf.resource
```

### Fallback Behavior

If `html2pdf` is not deployed, `ddPdfGenerator` automatically falls back to
`window.print()`, which opens the browser print dialog. The proposal is still
fully printable/saveable to PDF via the browser.

### Static Resource Metadata File

Create this file after uploading:
```
force-app/main/default/staticresources/html2pdf.resource-meta.xml
```
Contents:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Public</cacheControl>
    <contentType>text/javascript</contentType>
    <description>html2pdf.js library for client-side PDF generation from HTML</description>
</StaticResource>
```
