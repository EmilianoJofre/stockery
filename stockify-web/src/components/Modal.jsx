import { useEffect, useRef } from "react";
import { createPortal } from "react-dom";
import { HiXMark } from "react-icons/hi2";

const SIZE_CLASSES = {
  md: "max-w-md",
  lg: "max-w-lg",
  xl: "max-w-2xl",
};

export default function Modal({
  open,
  onClose,
  title,
  size = "lg",
  children,
  headerAction = null,
  disableClose = false,
}) {
  const panelRef = useRef(null);
  const handleClose = () => {
    if (disableClose) return;
    onClose();
  };

  useEffect(() => {
    if (!open) return;
    const handler = (e) => { if (e.key === "Escape") handleClose(); };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [disableClose, open, onClose]);

  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const timer = setTimeout(() => {
      const focusable = panelRef.current?.querySelector("input, select, textarea, button");
      focusable?.focus();
    }, 80);
    return () => clearTimeout(timer);
  }, [open]);

  if (!open) return null;

  return createPortal(
    <div className="fixed inset-0 z-[100] overflow-y-auto">
      <div className="flex min-h-full items-start justify-center p-4 pt-[6vh]">
        <div
          className="fixed inset-0 bg-ink/50 backdrop-blur-[2px]"
          aria-hidden="true"
          onClick={handleClose}
        />

        <div
          ref={panelRef}
          className={`modal-panel relative mb-10 w-full ${SIZE_CLASSES[size] || "max-w-lg"} rounded-[20px] border border-line bg-white shadow-xl`}
          role="dialog"
          aria-modal="true"
          aria-labelledby={title ? "modal-title" : undefined}
        >
          <div className="flex items-center justify-between border-b border-line px-6 py-5">
            <h2 id="modal-title" className="min-w-0 text-xl font-semibold tracking-[-0.03em] text-ink">
              {title}
            </h2>
            <div className="ml-4 flex items-center gap-2">
              {headerAction}
              <button
                aria-label="Cerrar"
                className="btn-ghost h-9 w-9 rounded-xl p-0"
                disabled={disableClose}
                onClick={handleClose}
                type="button"
              >
                <HiXMark className="text-xl" />
              </button>
            </div>
          </div>

          <div className="px-6 py-6">{children}</div>
        </div>
      </div>
    </div>,
    document.body
  );
}
