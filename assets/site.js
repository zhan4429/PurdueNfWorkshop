(() => {
  'use strict';
  const article = document.getElementById('workshop-content');
  const navigation = document.getElementById('chapter-nav');
  const sidebar = document.querySelector('.sidebar-inner');
  const contentsButton = document.querySelector('.contents-toggle');
  const headings = [...article.querySelectorAll('h2')];
  const progress = document.getElementById('reading-progress');
  const status = document.getElementById('copy-status');
  let statusTimer;

  const closeContents = () => {
    sidebar.classList.remove('is-open');
    contentsButton.setAttribute('aria-expanded', 'false');
    contentsButton.lastElementChild.textContent = '+';
  };
  headings.forEach((heading, index) => {
    const link = document.createElement('a');
    link.className = 'chapter-link';
    link.href = '#' + heading.id;
    const number = document.createElement('span');
    number.className = 'chapter-number';
    number.setAttribute('aria-hidden', 'true');
    number.textContent = String(index + 1).padStart(2, '0');
    link.append(number, document.createTextNode(heading.textContent));
    link.addEventListener('click', closeContents);
    navigation.append(link);
  });
  const chapterLinks = [...navigation.querySelectorAll('a')];
  contentsButton.addEventListener('click', () => {
    const opened = sidebar.classList.toggle('is-open');
    contentsButton.setAttribute('aria-expanded', String(opened));
    contentsButton.lastElementChild.textContent = opened ? '−' : '+';
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && sidebar.classList.contains('is-open')) {
      closeContents();
      contentsButton.focus();
    }
  });

  const announce = message => {
    clearTimeout(statusTimer);
    status.textContent = message;
    status.classList.add('visible');
    statusTimer = setTimeout(() => status.classList.remove('visible'), 2300);
  };
  const copyText = async text => {
    if (navigator.clipboard && window.isSecureContext) {
      try { await navigator.clipboard.writeText(text); return true; } catch (_) { /* Try local fallback. */ }
    }
    const field = document.createElement('textarea');
    field.value = text;
    field.setAttribute('readonly', '');
    field.style.cssText = 'position:fixed;left:-9999px;top:0;';
    document.body.append(field);
    field.select();
    let copied = false;
    try { copied = document.execCommand('copy'); } catch (_) { /* Selection remains available below. */ }
    field.remove();
    return copied;
  };
  article.querySelectorAll('pre').forEach(pre => {
    const code = pre.querySelector('code');
    if (!code) return;
    const wrapper = pre.closest('.highlighter-rouge') || pre.parentElement;
    const classText = wrapper.className + ' ' + code.className;
    const language = (classText.match(/language-([\w-]+)/) || [null, 'code'])[1];
    const toolbar = document.createElement('div');
    toolbar.className = 'code-toolbar';
    const label = document.createElement('span');
    label.className = 'code-language';
    label.textContent = language === 'bash' ? 'Bash / terminal' : language === 'groovy' ? 'Nextflow / Groovy' : language;
    const actions = document.createElement('div');
    actions.className = 'code-actions';
    if (code.textContent.split('\n').length > 27) {
      const expand = document.createElement('button');
      expand.className = 'expand-button';
      expand.type = 'button';
      expand.textContent = 'Expand';
      expand.setAttribute('aria-expanded', 'false');
      expand.addEventListener('click', () => {
        const expanded = wrapper.classList.toggle('is-expanded');
        expand.textContent = expanded ? 'Collapse' : 'Expand';
        expand.setAttribute('aria-expanded', String(expanded));
      });
      actions.append(expand);
    }
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'copy-button';
    button.setAttribute('aria-label', 'Copy this code block');
    button.innerHTML = '<svg viewBox="0 0 16 16" aria-hidden="true"><rect x="6" y="5" width="8" height="9" rx="1"/><path d="M10 3V2H2v9h2"/></svg><span>Copy</span>';
    let copyTimer;
    button.addEventListener('click', async () => {
      const copied = await copyText(code.textContent.replace(/\n$/, ''));
      button.focus({ preventScroll: true });
      if (copied) {
        button.classList.add('copied');
        button.querySelector('span').textContent = 'Copied!';
        announce('Code copied. Ready for your terminal or editor.');
        clearTimeout(copyTimer);
        copyTimer = setTimeout(() => {
          button.classList.remove('copied');
          button.querySelector('span').textContent = 'Copy';
        }, 2200);
      } else {
        const range = document.createRange();
        range.selectNodeContents(code);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
        announce('Code selected. Press Ctrl+C or ⌘C to copy.');
      }
    });
    actions.append(button);
    toolbar.append(label, actions);
    wrapper.prepend(toolbar);
    pre.tabIndex = 0;
    pre.setAttribute('aria-label', 'Scrollable ' + language + ' code example');
  });

  article.querySelectorAll('table').forEach(table => {
    const wrapper = document.createElement('div');
    wrapper.className = 'table-scroll';
    wrapper.tabIndex = 0;
    wrapper.setAttribute('role', 'region');
    wrapper.setAttribute('aria-label', 'Scrollable reference table');
    table.before(wrapper);
    wrapper.append(table);
  });

  let scheduled = false;
  const updateReading = () => {
    let active = 0;
    headings.forEach((heading, index) => {
      if (heading.getBoundingClientRect().top <= 170) active = index;
    });
    chapterLinks.forEach((link, index) => {
      if (index === active) link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    });
    const guideTop = document.getElementById('guide').offsetTop;
    const range = document.documentElement.scrollHeight - innerHeight - guideTop;
    const fraction = range > 0 ? Math.max(0, Math.min(1, (scrollY - guideTop) / range)) : 0;
    progress.style.width = fraction * 100 + '%';
    scheduled = false;
  };
  addEventListener('scroll', () => {
    if (!scheduled) { scheduled = true; requestAnimationFrame(updateReading); }
  }, { passive: true });
  addEventListener('resize', updateReading);
  if (document.fonts) document.fonts.ready.then(updateReading);
  updateReading();
})();
