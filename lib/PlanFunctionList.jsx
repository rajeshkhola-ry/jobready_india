import React from 'react';

// ==========================================
// 1. MASTER TOOLS REGISTRY
// Jab bhi naya tool bane, bas yahan 1 line add kar dijiye!
// ==========================================
const ALL_TOOLS = [
  { id: 'hd_photo', name: 'HD Photo Studio (1 time usage is free under Free plan)' },
  { id: 'ai_resume', name: 'AI Resume Builder (1 time usage is free under Free plan)' },
  { id: 'pdf_compress_single', name: 'PDF Compress (Single File) - set exact KB or MB target' },
  { id: 'pdf_compress_batch', name: 'Batch Compress (Multiple Files) - process many files' },
  { id: 'micro_canva', name: 'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)' },
  { id: 'resume_canvas', name: 'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)' },
  { id: 'poster_studio', name: 'Poster Studio (Canvas-based poster, banner, flyer, and local print)' },
  { id: 'pdf_ocr', name: 'PDF OCR & Extract (Extract and search text from PDF pages)' },
  { id: 'pdf_edit', name: 'Edit PDF (Edit PDF, then save and download)' }
];

// Helper icons (Green Tick & Red Cross)
const GreenTick = () => (
  <span style={{ color: '#22c55e', fontSize: '18px', fontWeight: 'bold' }}>✓</span>
);

const RedCross = () => (
  <span style={{ color: '#ef4444', fontSize: '18px', fontWeight: 'bold' }}>✕</span>
);

const PlanFunctionList = () => {
  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif' }}>
      <h2>Plan Comparison Matrix</h2>
      <p style={{ color: '#555' }}>
        Tick means feature included in that plan. Cross means not included.
      </p>

      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '15px' }}>
        <thead>
          <tr style={{ borderBottom: '2px solid #ddd', textAlign: 'left', padding: '12px' }}>
            <th style={{ padding: '12px' }}>Function Name</th>
            <th style={{ padding: '12px', textAlign: 'center' }}>FREE</th>
            <th style={{ padding: '12px', textAlign: 'center' }}>7 DAYS</th>
            <th style={{ padding: '12px', textAlign: 'center' }}>MONTHLY</th>
            <th style={{ padding: '12px', textAlign: 'center' }}>YEARLY</th>
            <th style={{ padding: '12px', textAlign: 'center' }}>LIFETIME</th>
          </tr>
        </thead>
        <tbody>
          {/* User Quota Row */}
          <tr style={{ borderBottom: '1px solid #eee' }}>
            <td style={{ padding: '12px', fontWeight: 'bold' }}>User Quota</td>
            <td style={{ textAlign: 'center' }}>5</td>
            <td style={{ textAlign: 'center' }}>50</td>
            <td style={{ textAlign: 'center' }}>150</td>
            <td style={{ textAlign: 'center' }}>1000</td>
            <td style={{ textAlign: 'center' }}>Unlimited</td>
          </tr>

          {/* Dynamic Tools Mapping */}
          {ALL_TOOLS.map((tool) => {
            // Rules for Free & 7-Day Plans
            const isFreeAllowed = ['hd_photo', 'ai_resume', 'pdf_compress_single'].includes(tool.id);
            const is7DaysAllowed = ['hd_photo', 'ai_resume', 'pdf_compress_single'].includes(tool.id);
            const isMonthlyAllowed = true;

            return (
              <tr key={tool.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '12px' }}>{tool.name}</td>
                <td style={{ textAlign: 'center' }}>{isFreeAllowed ? <GreenTick /> : <RedCross />}</td>
                <td style={{ textAlign: 'center' }}>{is7DaysAllowed ? <GreenTick /> : <RedCross />}</td>
                <td style={{ textAlign: 'center' }}>{isMonthlyAllowed ? <GreenTick /> : <RedCross />}</td>

                {/* YEARLY & LIFETIME are ALWAYS AUTOMATICALLY GREEN (TRUE) */}
                <td style={{ textAlign: 'center' }}><GreenTick /></td>
                <td style={{ textAlign: 'center' }}><GreenTick /></td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default PlanFunctionList;
