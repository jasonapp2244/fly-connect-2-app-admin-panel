#!/usr/bin/env node
/**
 * Convert markdown files in docs/ to .pdf using pdfkit + marked.
 * Produces clean, printable PDFs suitable for sharing with clients.
 *
 * Run:
 *   NODE_PATH="$(npm root -g)" node docs/_convert-to-pdf.js
 */

const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const PDFDocument = require('pdfkit');

// ── Layout constants (pt — 72 pt = 1 inch) ──────────────────
const PAGE_WIDTH  = 612;    // US Letter width
const PAGE_HEIGHT = 792;    // US Letter height
const MARGIN      = 72;     // 1 inch margins
const CONTENT_W   = PAGE_WIDTH - 2 * MARGIN;

// ── Brand colors ────────────────────────────────────────────
const PRIMARY = '#1A1D27';
const ACCENT  = '#D4F53C';
const SUBTLE  = '#8A8D9A';
const LINK    = '#0563C1';
const BG_CODE = '#F5F5F5';
const BORDER  = '#CCCCCC';

// ── Fonts (built-in Helvetica family; no extra assets needed) ─
const F_BODY     = 'Helvetica';
const F_BOLD     = 'Helvetica-Bold';
const F_ITALIC   = 'Helvetica-Oblique';
const F_BOLDITAL = 'Helvetica-BoldOblique';
const F_MONO     = 'Courier';

// ── Small helpers ───────────────────────────────────────────
function ensureSpace(doc, needed) {
  if (doc.y + needed > PAGE_HEIGHT - MARGIN) {
    doc.addPage();
  }
}

// Collapse the inline tokens into plain text + a list of ranges
// annotating bold/italic/code/link. Then render each span.
function renderInline(doc, tokens, baseOpts = {}) {
  for (let i = 0; i < tokens.length; i++) {
    const tok = tokens[i];
    const isLast = i === tokens.length - 1;
    switch (tok.type) {
      case 'text':
        writeSpan(doc, tok.text, { ...baseOpts }, { continued: !isLast });
        break;
      case 'strong':
        renderInline(doc, tok.tokens, { ...baseOpts, bold: true });
        if (!isLast) doc.text('', { continued: true });
        break;
      case 'em':
        renderInline(doc, tok.tokens, { ...baseOpts, italic: true });
        if (!isLast) doc.text('', { continued: true });
        break;
      case 'codespan':
        writeSpan(doc, tok.text, { ...baseOpts, mono: true, bg: BG_CODE }, { continued: !isLast });
        break;
      case 'link':
        writeSpan(doc, linkText(tok), { ...baseOpts, link: tok.href, color: LINK, underline: true },
          { continued: !isLast });
        break;
      case 'br':
        doc.text('', { continued: false });
        break;
      case 'del':
        renderInline(doc, tok.tokens, { ...baseOpts, strike: true });
        if (!isLast) doc.text('', { continued: true });
        break;
      case 'html': {
        const stripped = tok.text.replace(/<[^>]*>/g, '');
        if (stripped) writeSpan(doc, stripped, { ...baseOpts }, { continued: !isLast });
        break;
      }
      default:
        if (tok.text) writeSpan(doc, tok.text, { ...baseOpts }, { continued: !isLast });
    }
  }
}

function linkText(tok) {
  // marked gives tok.text which is already the rendered text
  return tok.text;
}

function pickFont(opts) {
  if (opts.mono) return F_MONO;
  if (opts.bold && opts.italic) return F_BOLDITAL;
  if (opts.bold) return F_BOLD;
  if (opts.italic) return F_ITALIC;
  return F_BODY;
}

function writeSpan(doc, text, opts, flowOpts) {
  if (!text) return;
  doc.font(pickFont(opts));
  doc.fillColor(opts.color || PRIMARY);
  doc.text(text, {
    continued: !!flowOpts.continued,
    underline: !!opts.underline,
    strike: !!opts.strike,
    link: opts.link || null,
  });
  // Reset to defaults
  doc.fillColor(PRIMARY);
  doc.font(F_BODY);
}

// ── Block renderers ─────────────────────────────────────────
function renderHeading(doc, tok) {
  const sizes = { 1: 22, 2: 17, 3: 14, 4: 12, 5: 11, 6: 11 };
  const size = sizes[tok.depth] || 11;
  const spaceBefore = tok.depth === 1 ? 16 : 12;
  const spaceAfter  = tok.depth === 1 ? 8 : 6;

  ensureSpace(doc, size + spaceBefore + spaceAfter + 20);
  doc.moveDown(spaceBefore / doc.currentLineHeight());
  doc.font(F_BOLD).fontSize(size).fillColor(PRIMARY);

  // Get plain text for the heading
  const headingText = tok.tokens.map(t => t.text || '').join('');
  doc.text(headingText, { paragraphGap: spaceAfter });

  doc.fillColor(PRIMARY).font(F_BODY).fontSize(11);
}

function renderParagraph(doc, tok) {
  ensureSpace(doc, 40);
  doc.font(F_BODY).fontSize(11).fillColor(PRIMARY);
  renderInline(doc, tok.tokens);
  doc.moveDown(0.5);
}

function renderList(doc, tok, depth = 0) {
  const indent = MARGIN + depth * 18;
  for (let i = 0; i < tok.items.length; i++) {
    const item = tok.items[i];
    const marker = tok.ordered ? `${(tok.start || 1) + i}.` : '•';
    ensureSpace(doc, 30);

    const yStart = doc.y;
    // Draw bullet/number
    doc.font(F_BODY).fontSize(11).fillColor(PRIMARY);
    doc.text(marker, indent, yStart, { width: 18, continued: false });

    // Render item body
    doc.x = indent + 18;
    const bodyWidth = PAGE_WIDTH - MARGIN - (indent + 18);

    for (const child of item.tokens) {
      if (child.type === 'text' || child.type === 'paragraph') {
        doc.font(F_BODY).fontSize(11).fillColor(PRIMARY);
        const startY = doc.y;
        doc.x = indent + 18;
        renderInline(doc, child.tokens || [{ type: 'text', text: child.text }]);
      } else if (child.type === 'list') {
        renderList(doc, child, depth + 1);
      } else if (child.type === 'code') {
        renderCode(doc, child);
      }
    }
    doc.x = MARGIN;
    doc.moveDown(0.2);
  }
  doc.moveDown(0.3);
}

function renderCode(doc, tok) {
  const lines = tok.text.split('\n');
  ensureSpace(doc, lines.length * 12 + 12);

  const startY = doc.y;
  doc.font(F_MONO).fontSize(9).fillColor(PRIMARY);

  // Background rect
  const blockHeight = lines.length * 12 + 8;
  doc.save();
  doc.rect(MARGIN, startY, CONTENT_W, blockHeight).fill(BG_CODE);
  doc.restore();

  doc.y = startY + 4;
  for (const line of lines) {
    ensureSpace(doc, 12);
    doc.font(F_MONO).fontSize(9).fillColor(PRIMARY).text(line, MARGIN + 6, doc.y, { width: CONTENT_W - 12 });
  }
  doc.font(F_BODY).fontSize(11);
  doc.moveDown(0.8);
}

function renderBlockquote(doc, tok) {
  for (const t of tok.tokens) {
    if (t.type === 'paragraph') {
      ensureSpace(doc, 40);
      const startY = doc.y;

      // Vertical rule on the left
      doc.save();
      doc.rect(MARGIN, startY, 3, doc.heightOfString(t.text, { width: CONTENT_W - 24 }) + 4)
        .fill(SUBTLE);
      doc.restore();

      doc.x = MARGIN + 12;
      doc.font(F_ITALIC).fontSize(11).fillColor(SUBTLE);
      renderInline(doc, t.tokens, { italic: true, color: SUBTLE });
      doc.x = MARGIN;
      doc.moveDown(0.5);
    }
  }
}

function renderHr(doc) {
  ensureSpace(doc, 20);
  doc.moveDown(0.5);
  doc.save();
  doc.moveTo(MARGIN, doc.y).lineTo(PAGE_WIDTH - MARGIN, doc.y).strokeColor(BORDER).lineWidth(0.5).stroke();
  doc.restore();
  doc.moveDown(0.5);
}

function renderTable(doc, tok) {
  const cols = tok.header.length;
  const colWidth = CONTENT_W / cols;
  const padding = 6;

  // Estimate row heights
  const rowHeight = (cells, isHeader) => {
    let max = 0;
    for (const cell of cells) {
      const text = cell.tokens.map(t => t.text || '').join('');
      doc.font(isHeader ? F_BOLD : F_BODY).fontSize(10);
      const h = doc.heightOfString(text, { width: colWidth - 2 * padding });
      if (h > max) max = h;
    }
    return max + 2 * padding;
  };

  const drawRow = (cells, isHeader) => {
    const h = rowHeight(cells, isHeader);
    ensureSpace(doc, h + 6);
    const y = doc.y;

    // Background for header
    if (isHeader) {
      doc.save();
      doc.rect(MARGIN, y, CONTENT_W, h).fill(BG_CODE);
      doc.restore();
    }

    // Cell borders + text
    for (let i = 0; i < cells.length; i++) {
      const cx = MARGIN + i * colWidth;
      doc.save();
      doc.rect(cx, y, colWidth, h).strokeColor(BORDER).lineWidth(0.4).stroke();
      doc.restore();

      const text = cells[i].tokens.map(t => t.text || '').join('');
      doc.font(isHeader ? F_BOLD : F_BODY).fontSize(10).fillColor(PRIMARY);
      doc.text(text, cx + padding, y + padding, { width: colWidth - 2 * padding });
    }
    doc.x = MARGIN;
    doc.y = y + h;
  };

  drawRow(tok.header, true);
  for (const row of tok.rows) drawRow(row, false);
  doc.font(F_BODY).fontSize(11);
  doc.moveDown(0.5);
}

// ── Top-level dispatcher ────────────────────────────────────
function renderTokens(doc, tokens) {
  for (const tok of tokens) {
    switch (tok.type) {
      case 'heading':    renderHeading(doc, tok); break;
      case 'paragraph':  renderParagraph(doc, tok); break;
      case 'list':       renderList(doc, tok); break;
      case 'code':       renderCode(doc, tok); break;
      case 'blockquote': renderBlockquote(doc, tok); break;
      case 'hr':         renderHr(doc); break;
      case 'table':      renderTable(doc, tok); break;
      case 'space':
      case 'html':       break;
      default:
        if (tok.text) {
          doc.font(F_BODY).fontSize(11).fillColor(PRIMARY).text(tok.text);
        }
    }
  }
}

// ── Header / footer ─────────────────────────────────────────
function drawFooter(doc, title) {
  const y = PAGE_HEIGHT - MARGIN + 24;
  doc.save();
  doc.font(F_BODY).fontSize(8).fillColor(SUBTLE);
  const pageNum = doc.bufferedPageRange().start + doc.bufferedPageRange().count;
  doc.text(
    `${title}    ·    Page ${doc.page.number}`,
    MARGIN,
    y,
    { width: CONTENT_W, align: 'center' },
  );
  doc.restore();
}

// ── File converter ──────────────────────────────────────────
async function convertFile(mdPath, pdfPath, title) {
  const markdown = fs.readFileSync(mdPath, 'utf8');
  const tokens = marked.lexer(markdown);

  const doc = new PDFDocument({
    size: 'LETTER',
    margin: MARGIN,
    bufferPages: true,
    info: {
      Title: title,
      Author: 'AppCurb Technologies',
      Creator: 'FlyConnect docs pipeline',
    },
  });

  const stream = fs.createWriteStream(pdfPath);
  doc.pipe(stream);

  // Document title at the top of page 1
  doc.font(F_BOLD).fontSize(24).fillColor(PRIMARY);
  doc.text(title, { align: 'left' });
  doc.moveDown(0.3);
  doc.save();
  doc.moveTo(MARGIN, doc.y).lineTo(PAGE_WIDTH - MARGIN, doc.y)
    .strokeColor(ACCENT).lineWidth(2).stroke();
  doc.restore();
  doc.moveDown(1);

  // Body
  doc.font(F_BODY).fontSize(11).fillColor(PRIMARY);
  renderTokens(doc, tokens);

  // Footers on all pages
  const range = doc.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i++) {
    doc.switchToPage(i);
    drawFooter(doc, title);
  }

  doc.end();
  return new Promise((resolve, reject) => {
    stream.on('finish', () => {
      const size = fs.statSync(pdfPath).size;
      console.log(`✓ ${path.basename(pdfPath)}  (${(size / 1024).toFixed(1)} KB)`);
      resolve();
    });
    stream.on('error', reject);
  });
}

// ── Main ────────────────────────────────────────────────────
(async () => {
  const docsDir = __dirname;
  const files = [
    { md: 'privacy-policy.md',    pdf: 'privacy-policy.pdf',    title: 'FlyConnect Privacy Policy' },
    { md: 'terms-of-service.md',  pdf: 'terms-of-service.pdf',  title: 'FlyConnect Terms of Service' },
    { md: 'store-listing.md',     pdf: 'store-listing.pdf',     title: 'FlyConnect Play Store Listing' },
  ];

  for (const f of files) {
    try {
      await convertFile(
        path.join(docsDir, f.md),
        path.join(docsDir, f.pdf),
        f.title,
      );
    } catch (err) {
      console.error(`\u2717 ${f.md}: ${err.message}`);
      console.error(err.stack);
      process.exit(1);
    }
  }
  console.log('\nAll docs converted to .pdf.');
})();
