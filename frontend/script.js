document.addEventListener('DOMContentLoaded', function() {
    loadFeedback();
    
    document.getElementById('feedbackForm').addEventListener('submit', function(e) {
        e.preventDefault();
        submitFeedback();
    });
    
    // Add real-time validation
    const nameInput = document.getElementById('name');
    const messageInput = document.getElementById('message');
    
    nameInput.addEventListener('input', validateForm);
    messageInput.addEventListener('input', validateForm);
});

function validateForm() {
    const name = document.getElementById('name').value;
    const message = document.getElementById('message').value;
    const errors = validateInput(name, message);
    
    // Update character counters
    updateCharacterCount('name', name.length, CONFIG.VALIDATION.MAX_NAME_LENGTH);
    updateCharacterCount('message', message.length, CONFIG.VALIDATION.MAX_MESSAGE_LENGTH);
    
    // Show validation errors
    const errorContainer = document.getElementById('validation-errors');
    if (errors.length > 0) {
        errorContainer.innerHTML = errors.map(error => `<div class="validation-error">${error}</div>`).join('');
        errorContainer.style.display = 'block';
    } else {
        errorContainer.style.display = 'none';
    }
}

function updateCharacterCount(fieldId, current, max) {
    const counter = document.getElementById(`${fieldId}-counter`);
    if (counter) {
        counter.textContent = `${current}/${max}`;
        counter.className = current > max ? 'char-counter over-limit' : 'char-counter';
    }
}

async function submitFeedback() {
    const name = document.getElementById('name').value.trim();
    const message = document.getElementById('message').value.trim();
    
    const errors = validateInput(name, message);
    if (errors.length > 0) {
        showError(errors.join(', '));
        return;
    }
    
    const correlationId = generateCorrelationId();
    
    try {
        const response = await fetchWithRetry(`${CONFIG.API_BASE_URL}/feedback`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlationId
            },
            body: JSON.stringify({
                name: name,
                message: message
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            document.getElementById('feedbackForm').reset();
            updateCharacterCount('name', 0, CONFIG.VALIDATION.MAX_NAME_LENGTH);
            updateCharacterCount('message', 0, CONFIG.VALIDATION.MAX_MESSAGE_LENGTH);
            loadFeedback();
            showSuccess('Feedback submitted successfully!');
        } else {
            throw new Error(data.error || 'Failed to submit feedback');
        }
    } catch (error) {
        console.error('Submit error:', error, 'Correlation ID:', correlationId);
        showError('Error submitting feedback: ' + error.message);
    }
}

async function loadFeedback() {
    const correlationId = generateCorrelationId();
    
    try {
        const response = await fetchWithRetry(`${CONFIG.API_BASE_URL}/feedback`, {
            headers: {
                'X-Correlation-ID': correlationId
            }
        });
        
        const data = await response.json();
        
        if (response.ok) {
            displayFeedback(data.feedback);
        } else {
            throw new Error(data.error || 'Failed to load feedback');
        }
    } catch (error) {
        console.error('Load error:', error, 'Correlation ID:', correlationId);
        showError('Error loading feedback: ' + error.message);
    }
}

function displayFeedback(feedbackList) {
    const container = document.getElementById('feedbackList');
    
    if (feedbackList.length === 0) {
        container.innerHTML = '<p>No feedback yet. Be the first to leave feedback!</p>';
        return;
    }
    
    container.innerHTML = feedbackList.map(feedback => `
        <div class="feedback-item">
            <div class="feedback-header">
                <span class="feedback-name">${escapeHtml(feedback.name)}</span>
                <div>
                    <span class="feedback-time">${formatDate(feedback.timestamp)}</span>
                    <button class="delete-btn" onclick="deleteFeedback('${feedback.feedback_id}')">Delete</button>
                </div>
            </div>
            <div class="feedback-message">${escapeHtml(feedback.message)}</div>
        </div>
    `).join('');
}

async function deleteFeedback(feedbackId) {
    if (!confirm('Are you sure you want to delete this feedback?')) {
        return;
    }
    
    const correlationId = generateCorrelationId();
    
    try {
        const response = await fetchWithRetry(`${CONFIG.API_BASE_URL}/feedback/${feedbackId}`, {
            method: 'DELETE',
            headers: {
                'X-Correlation-ID': correlationId
            }
        });
        
        const data = await response.json();
        
        if (response.ok) {
            loadFeedback();
            showSuccess('Feedback deleted successfully!');
        } else {
            throw new Error(data.error || 'Failed to delete feedback');
        }
    } catch (error) {
        console.error('Delete error:', error, 'Correlation ID:', correlationId);
        showError('Error deleting feedback: ' + error.message);
    }
}

function formatDate(timestamp) {
    if (!timestamp) return 'Unknown date';
    return new Date(timestamp).toLocaleString();
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showError(message) {
    const container = document.getElementById('feedbackList');
    container.innerHTML = `<div class="error">${message}</div>` + container.innerHTML;
    setTimeout(() => {
        const errorDiv = container.querySelector('.error');
        if (errorDiv) errorDiv.remove();
    }, 5000);
}

function showSuccess(message) {
    const container = document.getElementById('feedbackList');
    container.innerHTML = `<div style="color: #28a745; background-color: #d4edda; padding: 10px; border-radius: 4px; margin-bottom: 20px;">${message}</div>` + container.innerHTML;
    setTimeout(() => {
        const successDiv = container.querySelector('div[style*="color: #28a745"]');
        if (successDiv) successDiv.remove();
    }, 3000);
}