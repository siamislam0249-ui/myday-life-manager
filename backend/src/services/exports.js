'use strict';
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');

/* view = {
     title, period:'monthly'|'yearly',
     summary:{opening,income,expense,closing},
     categories:[{category,total,percent}],
     transactions:[{date,type,category,amount,note}],
     months?:[{label,opening,income,expense,closing}] } */

const money = (n) => Number(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// Neutralise spreadsheet formula injection in text cells.
const csvCell = (v) => {
  let s = v == null ? '' : String(v);
  if (typeof v === 'string' && /^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

function toCsv(view) {
  const rows = [
    [view.title], [],
    ['Opening Balance', view.summary.opening], ['Total Income', view.summary.income],
    ['Total Expense', view.summary.expense], ['Closing Balance', view.summary.closing], [],
  ];
  if (view.months) {
    rows.push(['Month', 'Opening', 'Income', 'Expense', 'Closing']);
    view.months.forEach((m) => rows.push([m.label, m.opening, m.income, m.expense, m.closing]));
    rows.push([]);
  }
  rows.push(['Category', 'Total Expense', 'Percent']);
  view.categories.forEach((c) => rows.push([c.category, c.total, `${c.percent}%`]));
  rows.push([], ['Date', 'Type', 'Category', 'Amount', 'Note']);
  view.transactions.forEach((t) => rows.push([t.date, t.type, t.category, t.amount, t.note]));
  return `\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n`; // BOM => Excel reads Bangla correctly
}

async function toXlsx(view) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'MyDay';
  const fmt = '#,##0.00';
  const head = (ws) => { ws.getRow(ws.rowCount).font = { bold: true }; };

  const s = wb.addWorksheet('Summary');
  s.getColumn(1).width = 24; s.getColumn(2).width = 18;
  s.addRow([view.title]).font = { bold: true, size: 14 };
  s.addRow([]);
  [['Opening Balance', view.summary.opening], ['Total Income', view.summary.income],
    ['Total Expense', view.summary.expense], ['Closing Balance', view.summary.closing]].forEach(([k, v]) => {
    const r = s.addRow([k, v]);
    r.getCell(1).font = { bold: true };
    r.getCell(2).numFmt = fmt;
  });

  if (view.months) {
    const ws = wb.addWorksheet('Months');
    ws.addRow(['Month', 'Opening', 'Income', 'Expense', 'Closing']); head(ws);
    view.months.forEach((m) => ws.addRow([m.label, m.opening, m.income, m.expense, m.closing]));
    [2, 3, 4, 5].forEach((i) => { ws.getColumn(i).numFmt = fmt; ws.getColumn(i).width = 16; });
    ws.getColumn(1).width = 14;
  }

  const c = wb.addWorksheet('Categories');
  c.addRow(['Category', 'Total Expense', 'Percent']); head(c);
  view.categories.forEach((x) => c.addRow([x.category, x.total, x.percent / 100]));
  c.getColumn(1).width = 24; c.getColumn(2).width = 16; c.getColumn(2).numFmt = fmt;
  c.getColumn(3).width = 10; c.getColumn(3).numFmt = '0.0%';

  const t = wb.addWorksheet('Transactions');
  t.addRow(['Date', 'Type', 'Category', 'Amount', 'Note']); head(t);
  view.transactions.forEach((x) => t.addRow([x.date, x.type, x.category, x.amount, x.note]));
  [18, 10, 20, 16, 40].forEach((w, i) => { t.getColumn(i + 1).width = w; });
  t.getColumn(4).numFmt = fmt;

  return Buffer.from(await wb.xlsx.writeBuffer());
}

function toPdf(view) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    if (process.env.PDF_FONT_PATH) { doc.registerFont('body', process.env.PDF_FONT_PATH); doc.font('body'); }

    const line = (cols, widths, size = 9) => {
      if (doc.y > 770) doc.addPage();
      const y = doc.y;
      let x = 40;
      cols.forEach((c, i) => { doc.fontSize(size).text(String(c), x, y, { width: widths[i] - 4, lineBreak: false, ellipsis: true }); x += widths[i]; });
      doc.y = y + size + 5;
      doc.x = 40;
    };

    doc.fontSize(18).fillColor('#155EEF').text(view.title, { align: 'left' }).moveDown(0.5).fillColor('#000');
    const s = view.summary;
    [['Opening Balance', s.opening], ['Total Income', s.income], ['Total Expense', s.expense], ['Closing Balance', s.closing]]
      .forEach(([k, v]) => line([k, `BDT ${money(v)}`], [180, 200], 11));

    if (view.months) {
      doc.moveDown().fontSize(13).text('Months').moveDown(0.3);
      line(['Month', 'Opening', 'Income', 'Expense', 'Closing'], [90, 105, 105, 105, 105]);
      view.months.forEach((m) => line([m.label, money(m.opening), money(m.income), money(m.expense), money(m.closing)], [90, 105, 105, 105, 105]));
    }

    doc.moveDown().fontSize(13).text('Category-wise expenses').moveDown(0.3);
    line(['Category', 'Total', '%'], [220, 120, 60]);
    view.categories.forEach((c) => line([c.category, money(c.total), `${c.percent}%`], [220, 120, 60]));

    doc.moveDown().fontSize(13).text('Transactions').moveDown(0.3);
    const w = [100, 55, 95, 80, 185];
    line(['Date', 'Type', 'Category', 'Amount', 'Note'], w);
    view.transactions.forEach((t) => line([t.date, t.type, t.category, money(t.amount), t.note], w));
    doc.end();
  });
}

module.exports = { toCsv, toXlsx, toPdf };
