const TW_CONFIG = {
    theme: {
        extend: {
            fontFamily: {
                display: ['"Space Grotesk"', 'sans-serif'],
                sans: ['Inter', 'sans-serif'],
                mono: ['"JetBrains Mono"', 'monospace'],
            },
        }
    }
};

const root = document.documentElement;

function loadTailwind() {
    root.classList.add('loading');

    let pending = 2;
    const reveal = () => {
        if (--pending === 0) {
            requestAnimationFrame(() => root.classList.remove('loading'));
        }
    };

    setTimeout(() => root.classList.remove('loading'), 2000);

    window.tailwind = { config: TW_CONFIG };

    const script = document.createElement('script');
    script.src = 'https://cdn.tailwindcss.com';
    script.onload = () => {
        window.tailwind.config = TW_CONFIG;
        reveal();
    };
    script.onerror = reveal;
    document.head.appendChild(script);

    return reveal;
}

function setupCodeBlocks() {
    document.querySelectorAll('.cb').forEach(block => {
        const pre = block.querySelector('pre');
        pre.classList.add('overflow-x-auto', 'p-5', 'font-mono', 'text-[15px]', 'leading-relaxed');
        block.classList.add('overflow-hidden', 'rounded-lg', 'border', 'border-[var(--line)]', 'bg-[var(--surface)]');

        const bar = document.createElement('div');
        bar.className = 'flex items-center justify-between border-b border-[var(--line)] bg-[var(--raise)]/60 px-4 py-2.5';
        bar.innerHTML = `<span class="flex items-center gap-2">
            <span class="h-3 w-3 rounded-full bg-[#FF5F57]"></span>
            <span class="h-3 w-3 rounded-full bg-[#FEBC2E]"></span>
            <span class="h-3 w-3 rounded-full bg-[#28C840]"></span>
            <span class="ml-2 font-mono text-xs uppercase tracking-wider text-[var(--dim)]">${block.dataset.label || 'bash'}</span>
        </span>`;

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'font-mono text-xs uppercase tracking-wider text-[var(--dim)] transition-colors hover:text-[var(--accent)]';
        button.textContent = 'copiar';
        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(pre.querySelector('code').textContent.trim());
                button.textContent = 'copiado ✓';
            } catch {
                button.textContent = 'erro';
            }

            setTimeout(() => { button.textContent = 'copiar'; }, 2000);
        });

        bar.appendChild(button);
        block.insertBefore(bar, pre);
    });
}

function setupMobileMenu() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('overlay');
    const toggle = open => {
        sidebar.classList.toggle('-translate-x-full', !open);
        overlay.classList.toggle('hidden', !open);
    };

    document.getElementById('menu-btn').addEventListener('click', () => toggle(true));
    overlay.addEventListener('click', () => toggle(false));
}

const revealPage = loadTailwind();

document.addEventListener('DOMContentLoaded', () => {
    revealPage();
    setupCodeBlocks();
    setupMobileMenu();
});
