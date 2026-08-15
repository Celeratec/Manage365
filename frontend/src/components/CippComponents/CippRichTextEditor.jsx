import React from "react";
import { Typography } from "@mui/material";
import { Controller } from "react-hook-form";
import get from "lodash/get";
import {
  MenuButtonBold,
  MenuButtonItalic,
  MenuControlsContainer,
  MenuDivider,
  MenuSelectHeading,
  RichTextEditor,
} from "mui-tiptap";
import StarterKit from "@tiptap/starter-kit";

const CippRichTextEditor = ({
  convertedName,
  formControl,
  validators,
  label,
  errors,
  ...other
}) => {
  const editorInstanceRef = React.useRef(null);
  const lastSetValue = React.useRef(null);

  return (
    <>
      <div>
        <Controller
          name={convertedName}
          control={formControl.control}
          rules={validators}
          render={({ field }) => {
            const { value, onChange, ref } = field;

            // Update content when value changes externally
            React.useEffect(() => {
              if (
                editorInstanceRef.current &&
                typeof value === "string" &&
                value !== lastSetValue.current
              ) {
                editorInstanceRef.current.commands.setContent(value || "", false);
                lastSetValue.current = value;
              }
            }, [value]);

            return (
              <>
                <Typography variant="subtitle2">{label}</Typography>
                <RichTextEditor
                  {...other}
                  immediatelyRender={false}
                  ref={ref}
                  extensions={[StarterKit]}
                  content=""
                  onCreate={({ editor }) => {
                    editorInstanceRef.current = editor;
                    // Set initial content when editor is created
                    if (typeof value === "string") {
                      editor.commands.setContent(value || "", false);
                      lastSetValue.current = value;
                    }
                  }}
                  onUpdate={({ editor }) => {
                    const newValue = editor.getHTML();
                    lastSetValue.current = newValue;
                    onChange(newValue);
                  }}
                  label={label}
                  renderControls={() => (
                    <MenuControlsContainer>
                      <MenuSelectHeading />
                      <MenuDivider />
                      <MenuButtonBold />
                      <MenuButtonItalic />
                    </MenuControlsContainer>
                  )}
                />
              </>
            );
          }}
        />
      </div>
      <Typography variant="subtitle3" color="error">
        {get(errors, convertedName, {}).message}
      </Typography>
    </>
  );
};

export default CippRichTextEditor;
