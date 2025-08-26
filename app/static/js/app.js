// ---- Section 1: preview images from /static/img/{animal}.jpg
const radios = document.querySelectorAll('input[name="animal"]');
const preview = document.getElementById('preview');
const img = document.getElementById('animal-img');
const placeholder = preview.querySelector('.placeholder');

radios.forEach(radio => {
    radio.addEventListener('change', () => {
        img.src = `/static/img/${radio.value}.jpg`;
        img.style.display = 'block';
        placeholder.style.display = 'none';
    });
});

// ---- Section 2: upload via FastAPI POST /upload
const MAX = 5 * 1024 * 1024; // 5 MB
const form = document.getElementById('uploadForm');
const fileInput = document.getElementById('fileInput');
const fileMsg = document.getElementById('fileMsg');

// Results table elements
const resultsCard = document.getElementById('uploadResults');
const resultsBody = document.getElementById('resultsBody');

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    resetMsg();

    const file = fileInput.files?.[0];
    if (!file) {
        showError('Please choose a file first.');
        resultsCard.hidden = true;
        return;
    }

    if (file.size > MAX) {
        showError(`File too large: ${(file.size / 1024 / 1024).toFixed(2)} MB (max 5 MB).`);
        resultsCard.hidden = true;
        return;
    }

    const formData = new FormData();
    formData.append('file', file, file.name);

    try {
        const res = await fetch('/upload', { method: 'POST', body: formData });

        if (!res.ok) {
            const txt = await res.text();
            throw new Error(txt || `Upload failed with status ${res.status}`);
        }

        const data = await res.json();

        // Success message
        fileMsg.textContent = 'Uploaded successfully.';
        fileMsg.classList.add('ok');
        fileMsg.style.display = 'block';

        // Populate (or replace) single row in results table
        resultsBody.innerHTML = `
      <tr>
        <td>${escapeHTML(data.filename)}</td>
        <td>${Number(data.size_mb).toFixed(2)}</td>
        <td>${escapeHTML(data.content_type || 'unknown')}</td>
      </tr>
    `;
        resultsCard.hidden = false;

        form.reset();
    } catch (err) {
        showError(err.message || 'Upload failed.');
        resultsCard.hidden = true;
    }
});

function resetMsg() {
    fileMsg.className = 'msg';
    fileMsg.style.display = 'none';
    fileMsg.textContent = '';
}

function showError(message) {
    fileMsg.textContent = message;
    fileMsg.classList.add('err');
    fileMsg.style.display = 'block';
}

// Basic HTML escaper to avoid injecting markup
function escapeHTML(str) {
    return String(str)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
}
