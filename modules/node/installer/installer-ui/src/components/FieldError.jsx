export default function FieldError({ message }) {
  if (!message) {
    return null;
  }

  return (
    <p className="mt-2 text-sm text-rose-300">{message}</p>
  );
}
