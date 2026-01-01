// Copy command functionality
function copyCommand() {
    const command = document.getElementById('install-command').textContent;
    const copyBtn = document.querySelector('.copy-btn');

    navigator.clipboard.writeText(command).then(() => {
        // Show success feedback
        showToast();

        // Update button appearance
        copyBtn.classList.add('copying');
        const originalText = copyBtn.innerHTML;
        copyBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20,6 9,17 4,12"></polyline></svg>Copied!';

        setTimeout(() => {
            copyBtn.classList.remove('copying');
            copyBtn.innerHTML = originalText;
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy command: ', err);
        // Fallback for older browsers
        fallbackCopyTextToClipboard(command);
    });
}

// Fallback copy method for older browsers
function fallbackCopyTextToClipboard(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.top = "0";
    textArea.style.left = "0";
    textArea.style.position = "fixed";
    textArea.style.opacity = "0";

    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
        const successful = document.execCommand('copy');
        if (successful) {
            showToast();
        }
    } catch (err) {
        console.error('Fallback: Oops, unable to copy', err);
    }

    document.body.removeChild(textArea);
}

// Show toast notification
function showToast() {
    const toast = document.getElementById('toast');
    toast.classList.add('show');

    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + C on the install command
    if ((e.ctrlKey || e.metaKey) && e.key === 'c') {
        const selection = window.getSelection();
        const commandElement = document.getElementById('install-command');

        if (selection.toString() === '' && commandElement.contains(selection.anchorNode)) {
            e.preventDefault();
            copyCommand();
        }
    }
});

// Add click-to-copy functionality to all code blocks
document.addEventListener('DOMContentLoaded', () => {
    const codeBlocks = document.querySelectorAll('.usage-item code');

    codeBlocks.forEach(codeBlock => {
        codeBlock.style.cursor = 'pointer';
        codeBlock.title = 'Click to copy';

        codeBlock.addEventListener('click', () => {
            const text = codeBlock.textContent;
            navigator.clipboard.writeText(text).then(() => {
                // Create temporary feedback
                const originalBg = codeBlock.style.backgroundColor;
                codeBlock.style.backgroundColor = '#059669';
                codeBlock.style.transition = 'background-color 0.2s';

                setTimeout(() => {
                    codeBlock.style.backgroundColor = originalBg;
                }, 1000);

                showToast();
            }).catch(err => {
                console.error('Failed to copy: ', err);
            });
        });
    });
});

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Add intersection observer for animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// Observe elements for animation
document.addEventListener('DOMContentLoaded', () => {
    const animatedElements = document.querySelectorAll('.feature, .usage-item');

    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(el);
    });
});

// Add version detection (placeholder for future enhancement)
function detectPlatform() {
    const platform = navigator.platform.toLowerCase();
    const userAgent = navigator.userAgent.toLowerCase();

    if (platform.includes('win')) {
        return 'windows';
    } else if (platform.includes('mac') || userAgent.includes('mac')) {
        return 'macos';
    } else if (platform.includes('linux') || userAgent.includes('linux')) {
        return 'linux';
    }
    return 'unix';
}

// Update command based on platform (future enhancement)
function updateCommandForPlatform() {
    const platform = detectPlatform();
    const commandElement = document.getElementById('install-command');
    const platformIndicator = document.querySelector('.platform-indicator');

    // For now, we keep the same command for all Unix-like systems
    // In the future, this could be enhanced for Windows support
    if (platform === 'windows') {
        platformIndicator.textContent = 'Windows (coming soon)';
        commandElement.textContent = '# Windows support coming soon';
    } else {
        platformIndicator.textContent = 'Unix/Linux/macOS';
    }
}

// Initialize platform detection on load
document.addEventListener('DOMContentLoaded', updateCommandForPlatform);

// Add dark mode toggle (optional enhancement)
function toggleDarkMode() {
    document.body.classList.toggle('dark-mode');
    localStorage.setItem('darkMode', document.body.classList.contains('dark-mode'));
}

// Load dark mode preference
document.addEventListener('DOMContentLoaded', () => {
    const darkMode = localStorage.getItem('darkMode') === 'true';
    if (darkMode) {
        document.body.classList.add('dark-mode');
    }
});

// Add error handling for network issues
window.addEventListener('online', () => {
    console.log('Network connection restored');
});

window.addEventListener('offline', () => {
    console.log('Network connection lost');
});

// Performance monitoring
if ('performance' in window) {
    window.addEventListener('load', () => {
        setTimeout(() => {
            const perfData = performance.getEntriesByType('navigation')[0];
            console.log(`Page load time: ${perfData.loadEventEnd - perfData.loadEventStart}ms`);
        }, 0);
    });
}
