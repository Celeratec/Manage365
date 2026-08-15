import PropTypes from "prop-types";

export const Logo = (props) => {
  const { height = 40 } = props;
  
  return (
    <img 
      src="/Main logo -CMYK.png" 
      alt="Manage365 Logo" 
      style={{ 
        height: typeof height === 'number' ? `${height}px` : height,
        width: 'auto',
        objectFit: 'contain'
      }} 
    />
  );
};

Logo.propTypes = {
  color: PropTypes.oneOf(["black", "primary", "white"]),
  height: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
};
