---
name: ui-and-styling
description: >
  Design system rules for revtriever-fe: Tailwind v4 tokens in index.css, shared/ui primitives built
  on Radix and cva, dark mode, money and date formatting, loading/empty/error states, toasts and
  confirmations. Use whenever building UI, styling, adding a primitive or formatting values.
  Triggers on: "componente", "component", "estilo", "style", "tailwind", "cor", "color", "tema",
  "dark mode", "tabela", "table", "moeda", "formatar", "skeleton", "empty state", "toast", "cva",
  "radix", "modal".
---

# UI & Styling — revtriever-fe

**Tailwind CSS v4** (`@tailwindcss/vite`, no `tailwind.config` — the tokens are CSS in
`src/index.css`) with our own primitives in `src/shared/ui`, using **Radix** (`@radix-ui/react-popover|select|tooltip`)
where behaviour is hard, **cva** for variants, `lucide-react` for icons and `cn()` for classes.
There is no shadcn CLI or `components.json`: every primitive is code we own.

## Tokens (`src/index.css`)

Everything is a CSS variable declared in `@theme`, so Tailwind generates the utilities.

- **Semantic tokens — the ones components use**: surfaces `bg-canvas`, `bg-surface`,
  `bg-surface-muted`; borders `border-border` / `border-border-strong`; text `text-content`,
  `text-content-muted`, `text-content-subtle`; actions `bg-accent` / `text-accent-contrast`;
  status `text-positive` (money, success), `text-caution` (attention), `text-critical` (failure,
  destructive). Radii `rounded-card` / `rounded-control`; shadows `shadow-card`, `shadow-popover`;
  `text-2xs` is the small size.
- **Palette tokens** (`brand-50…900`, `money-*`, `warn-*`, `danger-*`) are the raw scale behind the
  semantic ones and are used for tinted surfaces (`bg-danger-50`, `bg-money-50`). Prefer a semantic
  token when one fits.
- Never a raw hex/rgb in a component. A new color enters `index.css` as a token with a stated purpose.
- **Dark mode is a token flip**: `.dark` on `<html>` (toggled by `ThemeProvider`, preference kept in
  `localStorage` as `revtriever.theme`, options in `theme.types.ts`) overrides the semantic
  variables, so components using semantic classes need no `dark:` variant. `dark:` exists
  (`@custom-variant dark`) for the few tinted surfaces (see `shared/ui/alert.tsx`). Never ship a
  second set of components.
- Shared utility classes in `@layer components`: `.surface-card` (surface + border + radius +
  shadow) and `.numeric` (`tabular-nums`). Animations respect `prefers-reduced-motion`.
- Fonts: `--font-sans` / `--font-mono` (`font-mono` for ids and codes).

## Composition rules

1. **`shared/ui` is generic and domain-blind** (Button, Field, Modal, Alert, FailureAlert, EmptyState,
   Money, Skeleton, Pager, TabNav, SelectMenu, Tooltip, Toast, ConfirmDialog...). A component that
   knows what a charge or a gateway is lives in its feature (the lint boundary stops `shared` from
   importing features anyway).
2. **Variants come from `cva`**, no class-string juggling at the call site. Hand-write the variant
   props type and annotate the `cva(...)` result so `typedef` passes (`button.tsx`:
   `const buttonVariants: (props?: ButtonVariantProps) => string = cva(...)`;
   `ButtonProps extends VariantProps<typeof buttonVariants>`). Merge caller classes with `cn()`
   (`clsx` + `tailwind-merge`) from `@/shared/lib/cn`.
3. Props are an exported `readonly` interface above the component; spread the native element props
   when the primitive wraps one (`ButtonProps extends ButtonHTMLAttributes`).
4. **Every list/table/detail screen implements the four states**: loading (a skeleton of the real
   layout: `SkeletonTable`, `SkeletonText`, `Skeleton`, wrapped in `Loading label="..."` which sets
   `role="status"` and `aria-busy`), empty (`EmptyState` with the action that fills it), error
   (`FailureAlert` with retry where it makes sense) and content. A screen without an empty state is
   unfinished.
5. **Money is rendered by `<Money cents={...} />`** (`shared/ui/money.tsx`): BRL via
   `formatMoney(cents)` (`Intl.NumberFormat('pt-BR', BRL)` over cents), `.numeric`, and
   `tone="positive"` for recovered revenue. Amounts travel as integer cents; never `toFixed` or
   hand-built "R$" strings. Plain-text contexts use `formatMoney`.
6. **Dates and times** use `shared/lib/format/brazil-time.ts` (`describeDayAndTime`,
   `toLocalInput`, `fromLocalInput`, `brazilDayAgo`) and `DateField` / `PeriodRangePicker`; the API
   speaks UTC ISO instants and the screen speaks Brasília time.
7. Accessibility: icons are `aria-hidden`, icon-only buttons have `aria-label`, interactive
   elements are real `button`/`a`, focus rings come from the global `:focus-visible` style.
   `jsx-a11y` recommended rules are errors.
8. Component size: a primitive or a view is under 40 lines per function. Split subcomponents
   (`ButtonSpinner` next to `Button`), and move class computation to a small function
   (`inputClass` in `field.tsx`) — see `frontend-architecture`.

## Feedback

- **Toasts** come from `useToast()` (`@/app/providers/toast-provider`): `show(request)` with a
  `ToastRequest` (`tone` from `TOAST_TONES`, `title`, `detail`). Feature copy is built by pure
  functions in `<feature>-toasts.ts` (`cardForgottenToast`), past tense, saying what happened. API
  failures show the problem+json `detail`, not a generic text.
- **Destructive or irreversible actions** go through `ConfirmDialog` (`destructive`, `pending`) whose
  `description` names the consequence ("Cadastre outro antes da próxima cobrança"), never "Tem
  certeza?".
- Modals use `shared/ui/modal.tsx`. Anything over ~400ms shows progress (`Button loading`, skeleton).
- User-facing strings are pt-BR and written inline or in a `content/` file of the feature
  (`features/billing/content/checkout-copy.ts`); code identifiers and routes are English (see
  `conventions`).
