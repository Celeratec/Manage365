import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { escapeActionsCommand, escapeActionsProperty } from './validate-json.mjs';

test('escapeActionsCommand escapes percent signs', () => {
  assert.equal(escapeActionsCommand('50% complete'), '50%25 complete');
  assert.equal(escapeActionsCommand('100%'), '100%25');
});

test('escapeActionsCommand escapes newlines', () => {
  assert.equal(escapeActionsCommand('line1\nline2'), 'line1%0Aline2');
  assert.equal(escapeActionsCommand('multi\n\nline'), 'multi%0A%0Aline');
});

test('escapeActionsCommand escapes carriage returns', () => {
  assert.equal(escapeActionsCommand('line1\r\nline2'), 'line1%0D%0Aline2');
  assert.equal(escapeActionsCommand('text\rmore'), 'text%0Dmore');
});

test('escapeActionsCommand handles mixed special chars', () => {
  assert.equal(escapeActionsCommand('50%\n100%\r\n'), '50%25%0A100%25%0D%0A');
});

test('escapeActionsProperty escapes colons', () => {
  assert.equal(escapeActionsProperty('file:line:col'), 'file%3Aline%3Acol');
  assert.equal(escapeActionsProperty('src/app.ts:42:10'), 'src/app.ts%3A42%3A10');
});

test('escapeActionsProperty escapes commas', () => {
  assert.equal(escapeActionsProperty('a,b,c'), 'a%2Cb%2Cc');
  assert.equal(escapeActionsProperty('error, warning'), 'error%2C warning');
});

test('escapeActionsProperty escapes all command chars plus colon and comma', () => {
  assert.equal(
    escapeActionsProperty('file:10,20\n50%\r\ndone'),
    'file%3A10%2C20%0A50%25%0D%0Adone'
  );
});

test('escapeActionsProperty handles empty strings', () => {
  assert.equal(escapeActionsProperty(''), '');
});

test('escapeActionsCommand handles strings without special chars', () => {
  assert.equal(escapeActionsCommand('simple text'), 'simple text');
});

test('escapeActionsProperty handles realistic file paths', () => {
  assert.equal(
    escapeActionsProperty('frontend/src/data/config.json'),
    'frontend/src/data/config.json'
  );
});

test('escapeActionsCommand handles realistic error messages', () => {
  assert.equal(
    escapeActionsCommand('Unexpected token } in JSON at position 42'),
    'Unexpected token } in JSON at position 42'
  );
  assert.equal(
    escapeActionsCommand('Parse error on line 1:\n...{\n  "key": value\n---^'),
    'Parse error on line 1:%0A...{%0A  "key": value%0A---^'
  );
});

test('safeCodeSpan strips control characters', () => {
  const safeCodeSpan = (text) => {
    const cleaned = text.replace(/[\r\n\x00-\x1F\x7F]/g, '');
    const backtickRuns = cleaned.match(/`+/g) || [];
    const maxBackticks = backtickRuns.reduce((max, run) => Math.max(max, run.length), 0);
    const fence = '`'.repeat(maxBackticks + 1);
    return `${fence} ${cleaned} ${fence}`;
  };
  
  assert.equal(safeCodeSpan('file\nname.txt'), '` filename.txt `');
  assert.equal(safeCodeSpan('file\r\nname.txt'), '` filename.txt `');
  assert.equal(safeCodeSpan('file\x00name.txt'), '` filename.txt `');
});

test('safeCodeSpan handles backticks in text', () => {
  const safeCodeSpan = (text) => {
    const cleaned = text.replace(/[\r\n\x00-\x1F\x7F]/g, '');
    const backtickRuns = cleaned.match(/`+/g) || [];
    const maxBackticks = backtickRuns.reduce((max, run) => Math.max(max, run.length), 0);
    const fence = '`'.repeat(maxBackticks + 1);
    return `${fence} ${cleaned} ${fence}`;
  };
  
  assert.equal(safeCodeSpan('simple.txt'), '` simple.txt `');
  assert.equal(safeCodeSpan('file`name.txt'), '`` file`name.txt ``');
  assert.equal(safeCodeSpan('file``double.txt'), '``` file``double.txt ```');
});
