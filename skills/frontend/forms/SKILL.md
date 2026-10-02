---
name: forms
description: >
  Form patterns for revtriever-fe: React Hook Form + zod resolver, *.schema.ts files, form-to-API
  mappers, submit states, error display and accessibility. Use whenever building or changing a form,
  validation, input masks or handling submit errors. Triggers on: "form", "formulário", "input",
  "validação", "validation", "zod", "react-hook-form", "useForm", "submit", "erro de campo",
  "field error", "máscara", "schema".
---

# Forms — revtriever-fe

**React Hook Form 7 + `@hookform/resolvers/zod` + zod 3.** The schema lives in
`features/<feature>/schemas/<name>.schema.ts` and is the single source of truth for shape and
validation messages (pt-BR, because the user reads them). `*.schema.ts` files are exempt from
`typedef.variableDeclaration` so that `z.infer` keeps working.

```typescript
export const loginSchema = z.object({
    email: z.string().min(1, 'Informe seu e-mail').email('E-mail inválido'),
    password: z.string().min(1, 'Informe sua senha')
});
export type LoginInput = z.infer<typeof loginSchema>;
```

```typescript
const form: UseFormReturn<LoginInput> = useForm<LoginInput>({
    resolver: zodResolver(loginSchema),
    mode: 'onTouched',
    defaultValues: { email: '', password: '' }
});
```

Annotate `form` with the named `UseFormReturn<Input>` type (the `typedef` rule applies at the call
site). Always give `defaultValues` — every field starts as `''`, not `undefined`.

## Rules

1. **Mirror the API rules, don't invent new ones.** `passwordStepSchema`
   (`features/onboarding/schemas/signup.schema.ts`) states the same policy as the API (10+ chars,
   lower, upper, digit, special) so the user sees it before submitting; the API stays the authority.
2. **`mode: 'onTouched'`**: validate on blur, then on change. Never validate an untouched field.
3. **Use the shared `Field`** (`shared/ui/field.tsx`) for text inputs: it binds `<label htmlFor>`,
   sets `aria-invalid` and `aria-describedby`, renders the error with `role="alert"`, and adds the
   show/hide toggle for `type="password"`. Spread `form.register('name')` into it and pass
   `error={form.formState.errors.name?.message}`. Other inputs (`OtpInput`, `DateField`,
   `SelectMenu`, `TokenField`) live in `shared/ui` too — reuse before writing a new one.
4. **Server errors are form-level by default.** Keep the `ApiError` in `useState` and render
   `<FailureAlert error={failure} title="Não foi possível entrar" />` above the submit button (see
   `login-page.tsx`); it shows the API `detail` and, for 5xx, the `requestId`. The API's
   `meta.errors` entries are available through `error.fieldIssues()` (`{ path, message }[]`); when a
   server rule belongs to one input, map it with `form.setError(path, { message })` — no form does
   this yet, so keep it consistent if you introduce it.
5. **Disable submit while pending and say what is happening**: `Button` takes `loading`/`disabled`
   (`disabled={login.isPending}`, label "Entrando..."), never a dead button with no feedback.
6. **A form component does not navigate by itself when it can be reused.** The page (or the
   `onSubmit` handler it owns) decides what happens next; login branches on the outcome
   (`authenticated` / `totp_required` / `totp_enrollment_required`) to three destinations. Use
   `form.handleSubmit(async (input) => { ... })` and `mutation.mutateAsync` with try/catch.
7. **Forms render with `noValidate`** so zod, not the browser, owns validation and messages.
8. Keep every form function under 40 lines: split field groups into components that take the form
   (`address-fields.tsx`, `contact-fields.tsx` in `features/billing/components`), and move
   conversions out of the component.

## Form shape vs API shape

The form input is often not the API body (masks, `''` for empty optionals, split fields). Put the
conversion in `schemas/<name>.mapper.ts` as pure functions with their own spec:
`billingProfilePayload(input): BillingProfileInput` turns `''` into `null` and groups `contact` and
`address`; `EMPTY_BILLING_PROFILE_FORM` is the typed default; `expiryPartsOf` in `card.schema.ts`
splits `MM/AA` for the API. The API body type comes from the generated types via `types.ts`
(see `data-fetching`), the form type from `z.infer`.

## Masks and formats

Masking helpers are pure functions in `shared/lib/format/input-masks.ts` (`maskCardNumber`,
`maskCpfCnpj`, `maskPhoneBr`, `maskCep`, `maskDigits`). Validate on the digits (`card.schema.ts` strips
non-digits and runs a Luhn check) so the mask is cosmetic and the schema is the rule.

## Sensitive fields

- Passwords: `autoComplete="current-password"` / `"new-password"` and the `Field` toggle. Login's
  email field uses `autoComplete="username"`.
- Codes: `OtpInput` (separate boxes, paste fills them); for 2FA/email codes use numeric input mode
  and `one-time-code` autocomplete. Card fields use `cc-name`, `cc-number`, `cc-exp`, `cc-csc` and
  `inputMode="numeric"` (`card-form.tsx`).
- Never log form values, never put them in query params, never persist them in `localStorage`.
  Analytics events carry only whitelisted properties (see `data-fetching`), never field values.
