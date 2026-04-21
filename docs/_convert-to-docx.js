#!/usr/bin/env node
/**
 * Convert markdown files in docs/ to .docx using docx-js + marked.
 *
 * Run:
 *   node docs/_convert-to-docx.js
 */

const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, HeadingLevel,
  BorderStyle, WidthType, ShadingType, PageNumber, ExternalHyperlink,
  PageBreak,
} = require('docx');

// ── US Letter page size in DXA (1440 = 1 inch) ──────────────
const PAGE_WIDTH   = 12240;
const PAGE_HEIGHT  = 15840;
const MARGIN       = 1440;
const CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN;

const PRIMARY = '1A1D27';     // dark navy
const ACCENT  = 'D4F53C';     // neon yellow-green
const SUBTLE  = '8A8D9A';     // grey

// ── Style configuration (Inter fallback to Arial) ───────────
const STYLES = {
  default: {
    document: { run: { font: 'Calibri', size: 22 } }, // 11pt body
  },
  paragraphStyles: [
    {
      id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal',
      quickFormat: true,
      run: { size: 40, bold: true, font: 'Calibri', color: PRIMARY },
      paragraph: {
        spacing: { before: 360, after: 200 },
        outlineLevel: 0,
      },
    },
    {
      id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal',
      quickFormat: true,
      run: { size: 30, bold: true, font: 'Calibri', color: PRIMARY },
      paragraph: {
        spacing: { before: 300, after: 160 },
        outlineLevel: 1,
      },
    },
    {
      id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal',
      quickFormat: true,
      run: { size: 24, bold: true, font: 'Calibri', color: PRIMARY },
      paragraph: {
        spacing: { before: 240, after: 120 },
        outlineLevel: 2,
      },
    },
    {
      id: 'Heading4', name: 'Heading 4', basedOn: 'Normal', next: 'Normal',
      quickFormat: true,
      run: { size: 22, bold: true, font: 'Calibri', color: PRIMARY },
      paragraph: {
        spacing: { before: 200, after: 100 },
        outlineLevel: 3,
      },
    },
    {
      id: 'Hyperlink', name: 'Hyperlink', basedOn: 'Normal',
      run: { color: '0563C1', underline: { type: 'single' } },
    },
    {
      id: 'Code', name: 'Code', basedOn: 'Normal',
      run: { font: 'Consolas', size: 20 },
      paragraph: {
        spacing: { before: 120, after: 120 },
        shading: { type: ShadingType.CLEAR, fill: 'F5F5F5' },
      },
    },
  ],
};

const NUMBERING = {
  config: [
    {
      reference: 'bullets',
      levels: [{
        level: 0, format: LevelFormat.BULLET, text: '•',
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 720, hanging: 360 } } },
      }, {
        level: 1, format: LevelFormat.BULLET, text: '◦',
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 1440, hanging: 360 } } },
      }],
    },
    {
      reference: 'numbers',
      levels: [{
        level: 0, format: LevelFormat.DECIMAL, text: '%1.',
        alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 720, hanging: 360 } } },
      }],
    },
  ],
};

// ── Inline text parser ──────────────────────────────────────
// Parses the inline content of a marked token into TextRun[] or
// ExternalHyperlink children.
function inlineToRuns(tokens, opts = {}) {
  const runs = [];
  for (const tok of tokens) {
    switch (tok.type) {
      case 'text': {
        runs.push(new TextRun({
          text: tok.text,
          ...opts,
        }));
        break;
      }
      case 'strong': {
        const children = inlineToRuns(tok.tokens, { ...opts, bold: true });
        runs.push(...children);
        break;
      }
      case 'em': {
        const children = inlineToRuns(tok.tokens, { ...opts, italics: true });
        runs.push(...children);
        break;
      }
      case 'codespan': {
        runs.push(new TextRun({
          text: tok.text,
          font: 'Consolas',
          shading: { type: ShadingType.CLEAR, fill: 'F0F0F0' },
          ...opts,
        }));
        break;
      }
      case 'link': {
        runs.push(new ExternalHyperlink({
          link: tok.href,
          children: inlineToRuns(tok.tokens, { ...opts, style: 'Hyperlink' }),
        }));
        break;
      }
      case 'br': {
        runs.push(new TextRun({ break: 1 }));
        break;
      }
      case 'del': {
        runs.push(...inlineToRuns(tok.tokens, { ...opts, strike: true }));
        break;
      }
      case 'html': {
        // Ignore HTML tags, keep only visible text
        const stripped = tok.text.replace(/<[^>]*>/g, '');
        if (stripped) runs.push(new TextRun({ text: stripped, ...opts }));
        break;
      }
      default: {
        if (tok.text) runs.push(new TextRun({ text: tok.text, ...opts }));
      }
    }
  }
  return runs;
}

function renderHeading(tok) {
  const headingMap = {
    1: HeadingLevel.HEADING_1,
    2: HeadingLevel.HEADING_2,
    3: HeadingLevel.HEADING_3,
    4: HeadingLevel.HEADING_4,
    5: HeadingLevel.HEADING_5,
    6: HeadingLevel.HEADING_6,
  };
  return new Paragraph({
    heading: headingMap[tok.depth] || HeadingLevel.HEADING_1,
    children: inlineToRuns(tok.tokens),
  });
}

function renderParagraph(tok) {
  return new Paragraph({
    spacing: { before: 120, after: 120, line: 300 },
    children: inlineToRuns(tok.tokens),
  });
}

function renderList(tok) {
  const ref = tok.ordered ? 'numbers' : 'bullets';
  const paragraphs = [];

  for (const item of tok.items) {
    // marked gives item.tokens[0] as "list_item" wrapping paragraphs.
    // We flatten: first text -> a list paragraph; nested blocks become children paragraphs.
    const itemTokens = item.tokens;
    for (let i = 0; i < itemTokens.length; i++) {
      const child = itemTokens[i];
      if (child.type === 'text' || child.type === 'paragraph') {
        paragraphs.push(new Paragraph({
          numbering: i === 0 ? { reference: ref, level: 0 } : undefined,
          indent: i === 0 ? undefined : { left: 720 },
          children: inlineToRuns(child.tokens || [{ type: 'text', text: child.text }]),
        }));
      } else if (child.type === 'list') {
        // Nested list
        const nestedRef = child.ordered ? 'numbers' : 'bullets';
        for (const nestedItem of child.items) {
          for (const nt of nestedItem.tokens) {
            if (nt.type === 'text' || nt.type === 'paragraph') {
              paragraphs.push(new Paragraph({
                numbering: { reference: nestedRef, level: 1 },
                children: inlineToRuns(nt.tokens || [{ type: 'text', text: nt.text }]),
              }));
            }
          }
        }
      } else if (child.type === 'code') {
        paragraphs.push(renderCode(child));
      } else if (child.type === 'space') {
        // skip
      }
    }
  }
  return paragraphs;
}

function renderCode(tok) {
  const lines = tok.text.split('\n');
  return new Paragraph({
    style: 'Code',
    children: lines.flatMap((line, i) => [
      new TextRun({ text: line, font: 'Consolas', size: 20 }),
      i < lines.length - 1 ? new TextRun({ break: 1 }) : null,
    ].filter(Boolean)),
  });
}

function renderBlockquote(tok) {
  return tok.tokens.map(t => {
    if (t.type === 'paragraph') {
      return new Paragraph({
        indent: { left: 720 },
        border: {
          left: { style: BorderStyle.SINGLE, size: 12, color: SUBTLE, space: 12 },
        },
        children: inlineToRuns(t.tokens, { italics: true, color: SUBTLE }),
      });
    }
    return null;
  }).filter(Boolean);
}

function renderHr() {
  return new Paragraph({
    border: {
      bottom: { style: BorderStyle.SINGLE, size: 8, color: 'CCCCCC', space: 8 },
    },
    spacing: { before: 240, after: 240 },
  });
}

function renderTable(tok) {
  // tok has header (array of cells) and rows (array of arrays of cells)
  const columnCount = tok.header.length;
  const columnWidth = Math.floor(CONTENT_WIDTH / columnCount);
  const columnWidths = Array(columnCount).fill(columnWidth);
  // Adjust the last column to absorb rounding:
  columnWidths[columnCount - 1] = CONTENT_WIDTH - columnWidth * (columnCount - 1);

  const border = { style: BorderStyle.SINGLE, size: 4, color: 'CCCCCC' };
  const borders = { top: border, bottom: border, left: border, right: border };

  // Header row
  const headerRow = new TableRow({
    tableHeader: true,
    children: tok.header.map((cell, i) => new TableCell({
      borders,
      width: { size: columnWidths[i], type: WidthType.DXA },
      shading: { type: ShadingType.CLEAR, fill: 'F5F5F5' },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      children: [new Paragraph({
        children: inlineToRuns(cell.tokens, { bold: true }),
      })],
    })),
  });

  // Data rows
  const dataRows = tok.rows.map(row => new TableRow({
    children: row.map((cell, i) => new TableCell({
      borders,
      width: { size: columnWidths[i], type: WidthType.DXA },
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      children: [new Paragraph({
        children: inlineToRuns(cell.tokens),
      })],
    })),
  }));

  return new Table({
    width: { size: CONTENT_WIDTH, type: WidthType.DXA },
    columnWidths,
    rows: [headerRow, ...dataRows],
  });
}

// ── Top-level token dispatcher ──────────────────────────────
function renderTokens(tokens) {
  const out = [];
  for (const tok of tokens) {
    switch (tok.type) {
      case 'heading':    out.push(renderHeading(tok)); break;
      case 'paragraph':  out.push(renderParagraph(tok)); break;
      case 'list':       out.push(...renderList(tok)); break;
      case 'code':       out.push(renderCode(tok)); break;
      case 'blockquote': out.push(...renderBlockquote(tok)); break;
      case 'hr':         out.push(renderHr()); break;
      case 'table':      out.push(renderTable(tok)); break;
      case 'space':      break;
      case 'html':       break; // skip comments/raw HTML
      default:
        if (tok.tokens) {
          out.push(new Paragraph({ children: inlineToRuns(tok.tokens) }));
        } else if (tok.text) {
          out.push(new Paragraph({ children: [new TextRun(tok.text)] }));
        }
    }
  }
  return out;
}

// ── File converter ──────────────────────────────────────────
async function convertFile(mdPath, docxPath, title) {
  const markdown = fs.readFileSync(mdPath, 'utf8');
  const tokens = marked.lexer(markdown);
  const content = renderTokens(tokens);

  const doc = new Document({
    creator: 'AppCurb Technologies',
    title,
    styles: STYLES,
    numbering: NUMBERING,
    sections: [{
      properties: {
        page: {
          size: { width: PAGE_WIDTH, height: PAGE_HEIGHT },
          margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN },
        },
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [
              new TextRun({ text: `${title}    ·    Page `, size: 18, color: SUBTLE }),
              new TextRun({ children: [PageNumber.CURRENT], size: 18, color: SUBTLE }),
              new TextRun({ text: ' of ', size: 18, color: SUBTLE }),
              new TextRun({ children: [PageNumber.TOTAL_PAGES], size: 18, color: SUBTLE }),
            ],
          })],
        }),
      },
      children: content,
    }],
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync(docxPath, buffer);
  console.log(`✓ ${path.basename(docxPath)}  (${(buffer.length / 1024).toFixed(1)} KB)`);
}

// ── Main ────────────────────────────────────────────────────
(async () => {
  const docsDir = __dirname;
  const files = [
    { md: 'privacy-policy.md',    docx: 'privacy-policy.docx',    title: 'FlyConnect Privacy Policy' },
    { md: 'terms-of-service.md',  docx: 'terms-of-service.docx',  title: 'FlyConnect Terms of Service' },
    { md: 'store-listing.md',     docx: 'store-listing.docx',     title: 'FlyConnect Play Store Listing' },
  ];

  for (const f of files) {
    try {
      await convertFile(
        path.join(docsDir, f.md),
        path.join(docsDir, f.docx),
        f.title,
      );
    } catch (err) {
      console.error(`✗ ${f.md}: ${err.message}`);
      console.error(err.stack);
      process.exit(1);
    }
  }
  console.log('\nAll docs converted to .docx.');
})();
