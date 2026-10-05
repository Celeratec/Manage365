import {
  Stack,
  Typography,
  FormGroup,
  FormControlLabel,
  Checkbox,
  Button,
  Box,
  Paper,
} from "@mui/material";

const filterOptions = [
  {
    key: "officeTemp",
    label: "Office temp files (~$*)",
    description: "Created when editing Word, Excel, PowerPoint",
    defaultChecked: true,
  },
  {
    key: "tempFiles",
    label: "Temporary files (*.TMP, *.temp)",
    description: "System and app temp files",
    defaultChecked: true,
  },
  {
    key: "zeroByteFiles",
    label: "Zero-byte files",
    description: "Empty files that serve no purpose",
    defaultChecked: true,
  },
  {
    key: "systemJunk",
    label: "System junk (Thumbs.db, .DS_Store, desktop.ini)",
    description: "OS-generated metadata files",
    defaultChecked: true,
  },
  {
    key: "backupFiles",
    label: "Backup files (*.bak, *.old)",
    description: "May be intentional - review carefully",
    defaultChecked: false,
  },
];

export const StepConfigureFilters = ({ data, onUpdate, onNext, onBack }) => {
  const handleFilterChange = (key) => (event) => {
    onUpdate({
      filters: {
        ...data.filters,
        [key]: event.target.checked,
      },
    });
  };

  const hasAnyFilter = data.filters && Object.values(data.filters).some(Boolean);

  return (
    <Stack spacing={3}>
      <Typography variant="h6">
        Select which file types to scan for. We recommend starting with the common ones.
      </Typography>

      <FormGroup>
        {filterOptions.map((option) => (
          <Paper key={option.key} sx={{ p: 2, mb: 1 }} variant="outlined">
            <FormControlLabel
              control={
                <Checkbox
                  checked={data.filters?.[option.key] ?? option.defaultChecked}
                  onChange={handleFilterChange(option.key)}
                />
              }
              label={
                <Box>
                  <Typography variant="body1">{option.label}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {option.description}
                  </Typography>
                </Box>
              }
            />
          </Paper>
        ))}
      </FormGroup>

      <Box sx={{ display: "flex", justifyContent: "space-between", mt: 2 }}>
        <Button onClick={onBack}>Back</Button>
        <Button variant="contained" onClick={onNext} disabled={!hasAnyFilter}>
          Start Scan
        </Button>
      </Box>
    </Stack>
  );
};

export default StepConfigureFilters;
