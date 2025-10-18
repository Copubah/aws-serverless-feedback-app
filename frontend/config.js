// Configuration management
const CONFIG = {
    API_BASE_URL: 'https://oj2a69zca8.execute-api.us-east-1.amazonaws.com',
    MAX_RETRIES: 3,
    RETRY_DELAY: 1000,
    REQUEST_TIMEOUT: 10000,
    VALIDATION: {
        MIN_NAME_LENGTH: 2,
        MAX_NAME_LENGTH: 100,
        MIN_MESSAGE_LENGTH: 5,
        MAX_MESSAGE_LENGTH: 1000
    }
};

// Enhanced fetch with retry logic and timeout
async function fetchWithRetry(url, options = {}, retries = CONFIG.MAX_RETRIES) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), CONFIG.REQUEST_TIMEOUT);
    
    try {
        const response = await fetch(url, {
            ...options,
            signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok && retries > 0 && response.status >= 500) {
            await new Promise(resolve => setTimeout(resolve, CONFIG.RETRY_DELAY));
            return fetchWithRetry(url, options, retries - 1);
        }
        
        return response;
    } catch (error) {
        clearTimeout(timeoutId);
        
        if (retries > 0 && (error.name === 'AbortError' || error.name === 'TypeError')) {
            await new Promise(resolve => setTimeout(resolve, CONFIG.RETRY_DELAY));
            return fetchWithRetry(url, options, retries - 1);
        }
        
        throw error;
    }
}

// Input validation
function validateInput(name, message) {
    const errors = [];
    
    if (!name || name.trim().length < CONFIG.VALIDATION.MIN_NAME_LENGTH) {
        errors.push(`Name must be at least ${CONFIG.VALIDATION.MIN_NAME_LENGTH} characters long`);
    }
    
    if (name && name.length > CONFIG.VALIDATION.MAX_NAME_LENGTH) {
        errors.push(`Name must be less than ${CONFIG.VALIDATION.MAX_NAME_LENGTH} characters`);
    }
    
    if (!message || message.trim().length < CONFIG.VALIDATION.MIN_MESSAGE_LENGTH) {
        errors.push(`Message must be at least ${CONFIG.VALIDATION.MIN_MESSAGE_LENGTH} characters long`);
    }
    
    if (message && message.length > CONFIG.VALIDATION.MAX_MESSAGE_LENGTH) {
        errors.push(`Message must be less than ${CONFIG.VALIDATION.MAX_MESSAGE_LENGTH} characters`);
    }
    
    // Basic XSS prevention
    const xssPattern = /<script|javascript:|on\w+\s*=/i;
    if (xssPattern.test(name + message)) {
        errors.push('Invalid characters detected');
    }
    
    return errors;
}

// Generate correlation ID for request tracing
function generateCorrelationId() {
    return 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}