import { 
  Button, 
  Link, 
  Stack, 
  Dialog, 
  DialogActions, 
  DialogContent, 
  DialogTitle,
  Box,
  Typography,
  Card,
  CardContent,
  Chip,
  alpha,
  useMediaQuery,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { Grid } from "@mui/system";
import { CippWizardStepButtons } from "./CippWizardStepButtons";
import CippFormComponent from "../CippComponents/CippFormComponent";
import { CippDataTable } from "../CippTable/CippDataTable";
import { useWatch } from "react-hook-form";
import { Delete, UploadFile, Add, Download, TableChart } from "@mui/icons-material";
import { useEffect, useState } from "react";
import { getCippTranslation } from "../../utils/get-cipp-translation";

export const CippWizardCSVImport = (props) => {
  const {
    onNextStep,
    formControl,
    currentStep,
    onPreviousStep,
    fields,
    name,
    manualFields = false,
    nameToCSVMapping,
    fileName = "BulkUser",
  } = props;
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const tableData = useWatch({ control: formControl.control, name: name });
  const [newTableData, setTableData] = useState([]);
  const [open, setOpen] = useState(false);

  // Register form field with validation
  formControl.register(name, {
    validate: (value) => Array.isArray(value) && value.length > 0,
  });

  const handleRemoveItem = (row) => {
    if (row === undefined) return false;
    const rowKey = JSON.stringify(row);
    const index = tableData?.findIndex((item) => JSON.stringify(item) === rowKey);
    if (index === -1) return false;
    const newTableData = [...tableData];
    newTableData.splice(index, 1);
    setTableData(newTableData);
  };

  const handleAddItem = () => {
    const newRowData = formControl.getValues("addrow");
    if (newRowData === undefined) return false;
    const newTableData = [...tableData, newRowData];
    setTableData(newTableData);
    setOpen(false);
  };

  useEffect(() => {
    formControl.setValue(name, newTableData, {
      shouldValidate: true,
    });
  }, [newTableData]);

  const actions = [
    {
      icon: <Delete />,
      label: "Delete Row",
      confirmText: "Are you sure you want to delete this row?",
      customFunction: handleRemoveItem,
      noConfirm: true,
      category: "danger",
    },
  ];

  const rowCount = tableData?.length || 0;

  return (
    <Stack spacing={smDown ? 2 : 3}>
      {/* Header */}
      <Box sx={{ textAlign: "center" }}>
        <Box
          sx={{
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            width: smDown ? 56 : 72,
            height: smDown ? 56 : 72,
            borderRadius: "50%",
            bgcolor: alpha(theme.palette.primary.main, 0.1),
            color: "primary.main",
            mb: 1.5,
            border: `2px solid ${alpha(theme.palette.primary.main, 0.2)}`,
          }}
        >
          <UploadFile sx={{ fontSize: smDown ? 28 : 36 }} />
        </Box>
        <Typography variant={smDown ? "h6" : "h5"} fontWeight={600} gutterBottom>
          Import Data
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400, mx: 'auto' }}>
          Upload a CSV file or manually add entries below
        </Typography>
      </Box>

      {/* Upload Card */}
      <Card variant="outlined">
        <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
          <Stack direction="row" alignItems="center" justifyContent="space-between" flexWrap="wrap" gap={1}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Box
                sx={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  width: 36,
                  height: 36,
                  borderRadius: 1.5,
                  bgcolor: alpha(theme.palette.primary.main, 0.1),
                  color: "primary.main",
                }}
              >
                <UploadFile fontSize="small" />
              </Box>
              <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
                CSV Upload
              </Typography>
            </Stack>
            <Button
              component={Link}
              href={`data:text/csv;charset=utf-8,%EF%BB%BF${encodeURIComponent(fields.join(",") + "\n")}`}
              download={`${fileName}.csv`}
              size="small"
              variant="outlined"
              startIcon={<Download />}
            >
              {smDown ? "Template" : "Download Template"}
            </Button>
          </Stack>
        </Box>
        <CardContent sx={{ p: smDown ? 2 : 2.5 }}>
          <CippFormComponent
            nameToCSVMapping={nameToCSVMapping}
            type="CSVReader"
            name={name}
            formControl={formControl}
          />
        </CardContent>
      </Card>

      {/* Manual Entry */}
      {manualFields && (
        <Card variant="outlined">
          <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Box
                sx={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  width: 36,
                  height: 36,
                  borderRadius: 1.5,
                  bgcolor: alpha(theme.palette.info.main, 0.1),
                  color: "info.main",
                }}
              >
                <Add fontSize="small" />
              </Box>
              <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
                Manual Entry
              </Typography>
            </Stack>
          </Box>
          <CardContent sx={{ p: smDown ? 2 : 2.5 }}>
            <Grid container spacing={2}>
              {fields.map((field) => (
                <Grid size={{ md: 4, sm: 6, xs: 12 }} key={field}>
                  <CippFormComponent
                    name={`addrow.${field}`}
                    label={getCippTranslation(field)}
                    type="textField"
                    formControl={formControl}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") {
                        if (e.target.value === "") return false;
                        handleAddItem();
                        setTimeout(() => {
                          formControl.setValue(`addrow.${field}`, "");
                        }, 500);
                      }
                    }}
                  />
                </Grid>
              ))}
              <Grid size={{ md: 4, sm: 6, xs: 12 }} sx={{ display: 'flex', alignItems: 'flex-end' }}>
                <Button 
                  variant="contained" 
                  startIcon={<Add />}
                  onClick={() => handleAddItem()}
                >
                  Add Entry
                </Button>
              </Grid>
            </Grid>
          </CardContent>
        </Card>
      )}

      {!manualFields && (
        <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
          <Button 
            variant="outlined" 
            startIcon={<Add />}
            onClick={() => setOpen(true)}
          >
            Add Entry Manually
          </Button>
          <Dialog open={open} onClose={() => setOpen(false)} maxWidth="sm" fullWidth>
            <DialogTitle>Add New Entry</DialogTitle>
            <DialogContent>
              <Grid container spacing={2} sx={{ pt: 1 }}>
                {fields.map((field) => (
                  <Grid size={{ xs: 12 }} key={field}>
                    <CippFormComponent
                      name={`addrow.${field}`}
                      label={getCippTranslation(field)}
                      type="textField"
                      formControl={formControl}
                    />
                  </Grid>
                ))}
              </Grid>
            </DialogContent>
            <DialogActions sx={{ p: 2 }}>
              <Button variant="outlined" onClick={() => setOpen(false)}>
                Cancel
              </Button>
              <Button variant="contained" onClick={handleAddItem} startIcon={<Add />}>
                Add Entry
              </Button>
            </DialogActions>
          </Dialog>
        </Box>
      )}

      {/* Data Preview */}
      <Card variant="outlined">
        <Box sx={{ p: smDown ? 2 : 2.5, borderBottom: 1, borderColor: 'divider' }}>
          <Stack direction="row" alignItems="center" justifyContent="space-between">
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Box
                sx={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  width: 36,
                  height: 36,
                  borderRadius: 1.5,
                  bgcolor: alpha(theme.palette.success.main, 0.1),
                  color: "success.main",
                }}
              >
                <TableChart fontSize="small" />
              </Box>
              <Typography variant={smDown ? "subtitle1" : "h6"} fontWeight={600}>
                Data Preview
              </Typography>
            </Stack>
            <Chip 
              label={`${rowCount} ${rowCount === 1 ? 'row' : 'rows'}`}
              size="small"
              color={rowCount > 0 ? "success" : "default"}
              variant="outlined"
            />
          </Stack>
        </Box>
        <CippDataTable
          actions={actions}
          data={tableData}
          simple={false}
          simpleColumns={fields}
          noCard={true}
        />
      </Card>

      <CippWizardStepButtons
        currentStep={currentStep}
        onPreviousStep={onPreviousStep}
        onNextStep={onNextStep}
        formControl={formControl}
      />
    </Stack>
  );
};
